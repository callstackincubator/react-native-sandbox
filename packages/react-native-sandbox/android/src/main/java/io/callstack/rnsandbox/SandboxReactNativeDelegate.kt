package io.callstack.rnsandbox

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.Bundle
import android.util.Log
import android.view.View
import com.facebook.react.BaseReactPackage
import com.facebook.react.ReactHost
import com.facebook.react.ReactInstanceEventListener
import com.facebook.react.ReactPackage
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.JSBundleLoader
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.common.annotations.UnstableReactNativeAPI
import com.facebook.react.defaults.DefaultComponentsRegistry
import com.facebook.react.defaults.DefaultReactHostDelegate
import com.facebook.react.defaults.DefaultTurboModuleManagerDelegate
import com.facebook.react.fabric.ComponentFactory
import com.facebook.react.interfaces.fabric.ReactSurface
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.runtime.ReactHostImpl
import com.facebook.react.runtime.hermes.HermesInstance
import com.facebook.react.shell.MainReactPackage
import com.facebook.react.uimanager.ViewManager

class SandboxReactNativeDelegate(
    private val context: Context,
) {
    companion object {
        private const val TAG = "SandboxRNDelegate"

        private val sharedHosts = mutableMapOf<String, SharedReactHost>()

        private data class SharedReactHost(
            val reactHost: ReactHostImpl,
            val sandboxContext: Context,
            var refCount: Int,
        )
    }

    @JvmField var origin: String = ""

    var jsBundleSource: String = ""
    var allowedTurboModules: Set<String> = emptySet()
    var allowedOrigins: Set<String> = emptySet()

    @JvmField var hasOnMessageHandler: Boolean = false

    @JvmField var hasOnErrorHandler: Boolean = false
    var sandboxView: SandboxReactNativeView? = null

    private var reactHost: ReactHostImpl? = null
    private var reactSurface: ReactSurface? = null
    private var jsiStateHandle: Long = 0
    private var sandboxReactContext: ReactContext? = null
    private var ownsReactHost = false
    private var instanceEventListener: ReactInstanceEventListener? = null

    @OptIn(UnstableReactNativeAPI::class)
    fun loadReactNativeView(
        componentName: String,
        initialProperties: Bundle?,
        @Suppress("UNUSED_PARAMETER") launchOptions: Bundle?,
    ): View? {
        if (componentName.isEmpty() || jsBundleSource.isEmpty()) return null

        cleanup()

        val capturedBundleSource = jsBundleSource
        val capturedAllowedModules = allowedTurboModules

        try {
            val shared = if (origin.isNotEmpty()) sharedHosts[origin] else null

            val host: ReactHostImpl
            val sandboxContext: Context

            if (shared != null) {
                host = shared.reactHost
                sandboxContext = shared.sandboxContext
                shared.refCount++
                ownsReactHost = false
                Log.d(TAG, "Reusing shared ReactHost for origin '$origin' (refCount=${shared.refCount})")
            } else {
                sandboxContext = SandboxContextWrapper(context, origin)

                val packages: List<ReactPackage> =
                    listOf(
                        FilteredReactPackage(MainReactPackage(), capturedAllowedModules),
                    )

                val bundleLoader = createBundleLoader(capturedBundleSource) ?: return null

                val tmmDelegateBuilder = DefaultTurboModuleManagerDelegate.Builder()

                val bindingsInstaller = SandboxBindingsInstaller.create(this)

                val hostDelegate =
                    DefaultReactHostDelegate(
                        jsMainModulePath = capturedBundleSource,
                        jsBundleLoader = bundleLoader,
                        reactPackages = packages,
                        jsRuntimeFactory = HermesInstance(),
                        turboModuleManagerDelegateBuilder = tmmDelegateBuilder,
                        bindingsInstaller = bindingsInstaller,
                    )

                val componentFactory = ComponentFactory()
                DefaultComponentsRegistry.register(componentFactory)

                host =
                    ReactHostImpl(
                        sandboxContext,
                        hostDelegate,
                        componentFactory,
                        true,
                        true,
                    )

                ownsReactHost = true

                if (origin.isNotEmpty()) {
                    sharedHosts[origin] = SharedReactHost(host, sandboxContext, refCount = 1)
                    Log.d(TAG, "Created shared ReactHost for origin '$origin'")
                }
            }

            reactHost = host

            val listener =
                object : ReactInstanceEventListener {
                    override fun onReactContextInitialized(reactContext: ReactContext) {
                        sandboxReactContext = reactContext
                        if (jsiStateHandle != 0L) {
                            reactContext.runOnJSQueueThread {
                                SandboxJSIInstaller.nativeInstallErrorHandler(jsiStateHandle)
                            }
                        }
                    }
                }
            instanceEventListener = listener
            host.addReactInstanceEventListener(listener)

            val surface = host.createSurface(sandboxContext, componentName, initialProperties)
            reactSurface = surface

            surface.start()

            val activity = getActivity()
            if (activity != null) {
                host.onHostResume(activity)
            }

            return surface.view
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create React Native view: ${e.message}", e)
            sandboxView?.emitOnError(
                "LoadError",
                e.message ?: "Unknown error",
                e.stackTraceToString(),
                true,
            )
            return null
        }
    }

    fun reloadWithNewBundleSource(): Boolean {
        val host = reactHost ?: return false

        val newLoader = createBundleLoader(jsBundleSource) ?: return false

        try {
            val delegateField = ReactHostImpl::class.java.getDeclaredField("reactHostDelegate")
            delegateField.isAccessible = true
            val delegate = delegateField.get(host)

            val loaderField = delegate.javaClass.getDeclaredField("jsBundleLoader")
            loaderField.isAccessible = true

            val modifiersField = java.lang.reflect.Field::class.java.getDeclaredField("accessFlags")
            modifiersField.isAccessible = true
            modifiersField.setInt(
                loaderField,
                loaderField.modifiers and
                    java.lang.reflect.Modifier.FINAL
                        .inv(),
            )

            loaderField.set(delegate, newLoader)

            host.reload("jsBundleSource changed")
            Log.d(TAG, "Reloaded sandbox '$origin' with new bundle source via reflection")
            return true
        } catch (e: Exception) {
            Log.w(TAG, "Reflection-based bundle reload failed, falling back to full rebuild: ${e.message}")
            return false
        }
    }

    private fun createBundleLoader(bundleSource: String): JSBundleLoader? {
        if (bundleSource.isEmpty()) return null
        return when {
            bundleSource.startsWith("http://") || bundleSource.startsWith("https://") -> {
                JSBundleLoader.createFileLoader(bundleSource)
            }

            else -> {
                JSBundleLoader.createAssetLoader(context, "assets://$bundleSource", true)
            }
        }
    }

    fun onJSIBindingsInstalled(stateHandle: Long) {
        jsiStateHandle = stateHandle
    }

    fun postMessage(message: String) {
        val reactContext = sandboxReactContext
        val handle = jsiStateHandle
        Log.d(TAG, "postMessage to '$origin': context=${reactContext != null}, handle=$handle")
        if (reactContext == null || handle == 0L) return

        reactContext.runOnJSQueueThread {
            SandboxJSIInstaller.nativePostMessage(handle, message)
        }
    }

    @Suppress("unused")
    fun emitOnMessageFromJS(messageJson: String) {
        if (!hasOnMessageHandler) return

        UiThreadUtil.runOnUiThread {
            try {
                val data =
                    Arguments.createMap().apply {
                        putString("data", messageJson)
                    }
                sandboxView?.emitOnMessage(data)
            } catch (e: Exception) {
                Log.e(TAG, "Error emitting onMessage: ${e.message}", e)
            }
        }
    }

    @Suppress("unused")
    fun routeMessageFromJS(
        messageJson: String,
        targetOrigin: String,
    ): Boolean {
        if (origin == targetOrigin) {
            sandboxView?.emitOnError(
                "SelfTargetingError",
                "Cannot send message to self (sandbox '$targetOrigin')",
            )
            return false
        }

        // Routing handled entirely in C++ SandboxRegistry (see SandboxJSIInstaller.cpp)
        return false
    }

    @Suppress("unused")
    fun emitOnErrorFromJS(
        name: String,
        message: String,
        stack: String,
        isFatal: Boolean,
    ) {
        if (!hasOnErrorHandler) return

        UiThreadUtil.runOnUiThread {
            try {
                sandboxView?.emitOnError(name, message, stack, isFatal)
            } catch (e: Exception) {
                Log.e(TAG, "Error emitting onError: ${e.message}", e)
            }
        }
    }

    private fun getActivity(): Activity? {
        var ctx = context
        while (ctx is android.content.ContextWrapper) {
            if (ctx is Activity) return ctx
            ctx = ctx.baseContext
        }
        return null
    }

    fun cleanup() {
        if (jsiStateHandle != 0L) {
            SandboxJSIInstaller.nativeDestroy(jsiStateHandle)
            jsiStateHandle = 0
        }
        sandboxReactContext = null

        reactSurface?.let {
            it.stop()
            it.detach()
        }
        reactSurface = null

        val host = reactHost
        instanceEventListener?.let { listener ->
            host?.removeReactInstanceEventListener(listener)
        }
        instanceEventListener = null
        if (host != null) {
            if (origin.isNotEmpty()) {
                val shared = sharedHosts[origin]
                if (shared != null && shared.reactHost === host) {
                    shared.refCount--
                    if (shared.refCount <= 0) {
                        sharedHosts.remove(origin)
                        host.onHostDestroy()
                        host.destroy("sandbox cleanup", null)
                    }
                }
            } else if (ownsReactHost) {
                host.onHostDestroy()
                host.destroy("sandbox cleanup", null)
            }
        }
        reactHost = null
        ownsReactHost = false
    }

    fun destroy() {
        cleanup()
    }

    private class SandboxContextWrapper(
        base: Context,
        sandboxId: String,
    ) : ContextWrapper(base) {
        private val sandboxFilesDir = java.io.File(base.filesDir, "sandbox_$sandboxId").also { it.mkdirs() }

        override fun getFilesDir(): java.io.File = sandboxFilesDir

        override fun getApplicationContext(): Context = this
    }

    private class FilteredReactPackage(
        private val delegate: MainReactPackage,
        private val allowedModules: Set<String>,
    ) : BaseReactPackage() {
        override fun getModule(
            name: String,
            reactContext: ReactApplicationContext,
        ): NativeModule? {
            if (!allowedModules.contains(name)) {
                Log.w(TAG, "Blocked module '$name' — not in allowedTurboModules")
                return null
            }
            return delegate.getModule(name, reactContext)
        }

        override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
            val delegateProvider = delegate.getReactModuleInfoProvider()
            return ReactModuleInfoProvider {
                delegateProvider.getReactModuleInfos().filterKeys { allowedModules.contains(it) }
            }
        }

        override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> =
            delegate.createViewManagers(reactContext)
    }
}
