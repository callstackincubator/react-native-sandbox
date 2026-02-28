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
    }

    var origin: String = ""
        set(value) {
            if (field == value) return
            if (field.isNotEmpty()) {
                SandboxRegistry.unregister(field)
            }
            field = value
            if (value.isNotEmpty()) {
                SandboxRegistry.register(value, this, allowedOrigins)
            }
        }

    var jsBundleSource: String = ""
    var allowedTurboModules: Set<String> = emptySet()
    var allowedOrigins: Set<String> = emptySet()
        set(value) {
            field = value
            if (origin.isNotEmpty()) {
                SandboxRegistry.register(origin, this, value)
            }
        }

    @JvmField var hasOnMessageHandler: Boolean = false

    @JvmField var hasOnErrorHandler: Boolean = false
    var sandboxView: SandboxReactNativeView? = null

    private var reactHost: ReactHostImpl? = null
    private var reactSurface: ReactSurface? = null
    private var jsiStateHandle: Long = 0
    private var sandboxReactContext: ReactContext? = null

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
        val sandboxId = System.identityHashCode(this).toString(16)
        val sandboxContext = SandboxContextWrapper(context, sandboxId)

        try {
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

            val host =
                ReactHostImpl(
                    sandboxContext,
                    hostDelegate,
                    componentFactory,
                    true,
                    true,
                )

            reactHost = host

            host.addReactInstanceEventListener(
                object : ReactInstanceEventListener {
                    override fun onReactContextInitialized(reactContext: ReactContext) {
                        sandboxReactContext = reactContext
                    }
                },
            )

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

        return routeMessage(messageJson, targetOrigin)
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

    fun routeMessage(
        message: String,
        targetId: String,
    ): Boolean {
        val target = SandboxRegistry.find(targetId)
        Log.d(TAG, "routeMessage from '$origin' to '$targetId': target found=${target != null}")
        if (target == null) return false

        if (!SandboxRegistry.isPermittedFrom(origin, targetId)) {
            Log.w(TAG, "routeMessage DENIED: '$origin' -> '$targetId'")
            sandboxView?.emitOnError(
                "AccessDeniedError",
                "Access denied: Sandbox '$origin' is not permitted to send messages to '$targetId'",
            )
            return false
        }

        Log.d(TAG, "routeMessage PERMITTED: '$origin' -> '$targetId', delivering...")
        target.postMessage(message)
        return true
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

        reactHost?.let {
            it.onHostDestroy()
            it.destroy("sandbox cleanup", null)
        }
        reactHost = null
    }

    fun destroy() {
        if (origin.isNotEmpty()) {
            SandboxRegistry.unregister(origin)
        }
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
