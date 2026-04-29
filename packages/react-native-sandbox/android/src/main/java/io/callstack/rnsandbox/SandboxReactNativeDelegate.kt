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
        private val registeredSubstitutionPackages = mutableListOf<ReactPackage>()
        private val registeredHostPackages = mutableListOf<ReactPackage>()

        /**
         * Register ReactPackage instances that provide substitution modules.
         * Call this from your Application.onCreate() before any sandbox views load.
         */
        @JvmStatic
        fun registerSubstitutionPackages(vararg packages: ReactPackage) {
            registeredSubstitutionPackages.addAll(packages)
        }

        /**
         * Register the host app's autolinked ReactPackage instances so that
         * allowed (non-substituted) third-party modules can be resolved inside
         * the sandbox. Without this, only modules from MainReactPackage (RN
         * built-ins) are available.
         *
         * Typically called from Application.onCreate():
         * ```
         * SandboxReactNativeDelegate.registerHostPackages(PackageList(this).packages)
         * ```
         */
        @JvmStatic
        fun registerHostPackages(packages: List<ReactPackage>) {
            registeredHostPackages.addAll(packages)
        }

        private data class SharedReactHost(
            val reactHost: ReactHostImpl,
            val sandboxContext: Context,
            var refCount: Int,
        )
    }

    @JvmField var origin: String = ""

    var jsBundleSource: String = ""
    var allowedTurboModules: Set<String> = emptySet()
    var turboModuleSubstitutions: Map<String, String> = emptyMap()
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

                val capturedSubstitutions = turboModuleSubstitutions.toMap()
                val capturedSubstitutionPackages = registeredSubstitutionPackages.toList()
                val capturedHostPackages = registeredHostPackages.toList()
                val capturedOrigin = origin

                val packages: List<ReactPackage> =
                    listOf(
                        FilteredReactPackage(
                            MainReactPackage(),
                            capturedHostPackages,
                            capturedAllowedModules,
                            capturedSubstitutions,
                            capturedSubstitutionPackages,
                            capturedOrigin,
                        ),
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
            Log.d(TAG, "Reflection-based bundle reload failed, falling back to full rebuild: ${e.message}")
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

        /**
         * On Android 12 and below, Context.registerComponentCallbacks() delegates to
         * getApplicationContext().registerComponentCallbacks(). Since getApplicationContext()
         * returns `this` in SandboxContextWrapper, that causes infinite recursion and a
         * StackOverflowError. Android 13+ fixed this in ContextWrapper by delegating to mBase
         * directly. We mirror that fix here to support older platforms.
         */
        override fun registerComponentCallbacks(callback: android.content.ComponentCallbacks) {
            baseContext.applicationContext.registerComponentCallbacks(callback)
        }

        override fun unregisterComponentCallbacks(callback: android.content.ComponentCallbacks) {
            baseContext.applicationContext.unregisterComponentCallbacks(callback)
        }
    }

    private class FilteredReactPackage(
        private val delegate: MainReactPackage,
        private val hostPackages: List<ReactPackage>,
        private val allowedModules: Set<String>,
        private val substitutions: Map<String, String>,
        private val substitutionPackages: List<ReactPackage>,
        private val origin: String,
    ) : BaseReactPackage() {
        private val substitutedInstances = java.util.concurrent.ConcurrentHashMap<String, NativeModule>()

        private val effectiveAllowed: Set<String> by lazy {
            allowedModules + substitutions.keys
        }

        override fun getModule(
            name: String,
            reactContext: ReactApplicationContext,
        ): NativeModule? {
            val resolvedName = substitutions[name]
            if (resolvedName != null) {
                substitutedInstances[name]?.let { return it }

                for (pkg in substitutionPackages) {
                    val module =
                        if (pkg is BaseReactPackage) {
                            pkg.getModule(resolvedName, reactContext)
                        } else {
                            pkg.createNativeModules(reactContext).firstOrNull { it.name == resolvedName }
                        }
                    if (module != null) {
                        if (module is SandboxAwareModule) {
                            module.configureSandbox(origin, name, resolvedName)
                        }
                        substitutedInstances[name] = module
                        Log.d(TAG, "Substituted '$name' -> '$resolvedName' (${module.javaClass.simpleName})")
                        return module
                    }
                }
                Log.w(TAG, "Substitution target '$resolvedName' not found in any package for '$name'")
                return null
            }

            if (!effectiveAllowed.contains(name)) {
                return null
            }

            delegate.getModule(name, reactContext)?.let { return it }

            for (pkg in hostPackages) {
                val module =
                    if (pkg is BaseReactPackage) {
                        pkg.getModule(name, reactContext)
                    } else {
                        pkg.createNativeModules(reactContext).firstOrNull { it.name == name }
                    }
                if (module != null) return module
            }
            return null
        }

        override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
            val delegateProvider = delegate.getReactModuleInfoProvider()
            val hostProviders =
                hostPackages.mapNotNull {
                    (it as? BaseReactPackage)?.getReactModuleInfoProvider()
                }
            val substitutionProviders =
                substitutionPackages.mapNotNull {
                    (it as? BaseReactPackage)?.getReactModuleInfoProvider()
                }
            return ReactModuleInfoProvider {
                val infos =
                    delegateProvider
                        .getReactModuleInfos()
                        .filterKeys { effectiveAllowed.contains(it) }
                        .toMutableMap()
                for (provider in hostProviders) {
                    infos.putAll(provider.getReactModuleInfos().filterKeys { effectiveAllowed.contains(it) })
                }
                for ((requestedName, resolvedName) in substitutions) {
                    for (provider in substitutionProviders) {
                        val subInfos = provider.getReactModuleInfos()
                        subInfos[resolvedName]?.let { infos[requestedName] = it }
                    }
                }
                infos
            }
        }

        override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> =
            delegate.createViewManagers(reactContext)
    }
}
