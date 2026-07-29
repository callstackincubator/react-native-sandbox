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
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

class SandboxReactNativeDelegate(
    private val context: Context,
) {
    companion object {
        private const val TAG = "SandboxRNDelegate"

        private const val REMOTE_BUNDLE_CONNECT_TIMEOUT_MS = 10_000
        private const val REMOTE_BUNDLE_READ_TIMEOUT_MS = 15_000
        private const val REMOTE_BUNDLE_DOWNLOAD_TIMEOUT_MS = 20_000L

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
            // idleTTLMs: max-wins across all registering delegates for this origin.
            // A delegate with a tight TTL will observe the longer-lived behavior if
            // a peer has already registered a larger value. See idleTTL JSDoc.
            var idleTTLMs: Long = 0,
            // Incremented each time a deferred destroy is scheduled so that a
            // re-mount within the TTL window can cancel the pending destroy.
            // All accesses must be on the main thread; use AtomicLong to make
            // the increment-and-read sequence safe if that invariant ever relaxes.
            val destroyGeneration: java.util.concurrent.atomic.AtomicLong =
                java.util.concurrent.atomic
                    .AtomicLong(0),
            var jsiStateHandle: Long = 0,
        )

        private val nextSurfaceId =
            java.util.concurrent.atomic
                .AtomicLong(0)
        private val delegateBySurfaceId = java.util.concurrent.ConcurrentHashMap<String, SandboxReactNativeDelegate>()

        /**
         * Finds a delegate by its surface ID. Called from JNI when postMessage
         * includes a __sandboxSurfaceId for per-surface routing.
         */
        @JvmStatic
        fun findBySurfaceId(id: String): SandboxReactNativeDelegate? = delegateBySurfaceId[id]
    }

    @JvmField var origin: String = ""

    @JvmField var surfaceId: String = ""

    var jsBundleSource: String = ""
    var allowedTurboModules: Set<String> = emptySet()
    var turboModuleSubstitutions: Map<String, String> = emptyMap()
    var allowedOrigins: Set<String> = emptySet()
    var idleTTLMs: Long = 0

    @JvmField var hasOnMessageHandler: Boolean = false

    @JvmField var hasOnErrorHandler: Boolean = false
    var sandboxView: SandboxReactNativeView? = null

    private var reactHost: ReactHostImpl? = null
    private var reactSurface: ReactSurface? = null
    private var jsiStateHandle: Long = 0
    private var sandboxReactContext: ReactContext? = null
    private var ownsReactHost = false
    private var instanceEventListener: ReactInstanceEventListener? = null
    private var registryDelegateHandle: Long = 0
    private val pendingHostMessages = mutableListOf<String>()

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

        // Generate a unique surface ID for per-surface message routing
        surfaceId = "surface:${nextSurfaceId.incrementAndGet()}"
        delegateBySurfaceId[surfaceId] = this

        try {
            val shared = if (origin.isNotEmpty()) sharedHosts[origin] else null

            val host: ReactHostImpl
            val sandboxContext: Context

            if (shared != null) {
                host = shared.reactHost
                sandboxContext = shared.sandboxContext
                shared.refCount++
                shared.idleTTLMs = maxOf(shared.idleTTLMs, idleTTLMs)
                ownsReactHost = false
                Log.d(TAG, "Reusing shared ReactHost for origin '$origin' (refCount=${shared.refCount})")

                // Register this delegate in the C++ SandboxRegistry so that
                // postMessage/onError broadcasts from the shared VM reach
                // every view, not just the first one that created the host.
                registryDelegateHandle = SandboxJSIInstaller.nativeRegisterDelegate(origin, this)

                // Grab the JSI state handle from the first view so Host→JS
                // messaging (ref.postMessage) works for this view too.
                jsiStateHandle = shared.jsiStateHandle

                // The ReactContext is already initialized; grab it directly
                // so postMessage can call runOnJSQueueThread.
                sandboxReactContext = host.currentReactContext
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
                    ) + getExpoPackages()

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

                // For a remote (http/https) bundle, disable developer support on this
                // ReactHost. With dev support enabled the runtime ignores jsBundleLoader
                // and fetches the bundle from the Metro dev server using jsMainModulePath,
                // turning the URL into http://localhost:8081/<url>.bundle (a 404). Local
                // sources ("index"/asset names) keep dev support so Fast Refresh works.
                val isRemoteBundle =
                    capturedBundleSource.startsWith("http://") ||
                        capturedBundleSource.startsWith("https://")
                host =
                    ReactHostImpl(
                        sandboxContext,
                        hostDelegate,
                        componentFactory,
                        !isRemoteBundle,
                        !isRemoteBundle,
                    )

                ownsReactHost = true

                if (origin.isNotEmpty()) {
                    sharedHosts[origin] = SharedReactHost(host, sandboxContext, refCount = 1, idleTTLMs = idleTTLMs)
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

            val surface = host.createSurface(sandboxContext, componentName, initialProperties.withSurfaceId())
            reactSurface = surface

            val activity = getActivity()
            if (activity != null) {
                host.onHostResume(activity)
            }

            surface.start()

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

    private fun getExpoPackages(): List<ReactPackage> {
        if (!BuildConfig.HAS_EXPO_MODULES) return emptyList()
        return try {
            val clazz = Class.forName("io.callstack.rnsandbox.ExpoIntegration")
            val instance = clazz.getDeclaredField("INSTANCE").get(null)
            @Suppress("UNCHECKED_CAST")
            clazz.getDeclaredMethod("createPackages").invoke(instance) as List<ReactPackage>
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load Expo packages", e)
            emptyList()
        }
    }

    private fun createBundleLoader(bundleSource: String): JSBundleLoader? {
        if (bundleSource.isEmpty()) return null
        return when {
            bundleSource.startsWith("http://") || bundleSource.startsWith("https://") -> {
                // createFileLoader(url) treats its argument as a local path and never
                // downloads. Prefetch to a cache file on a worker thread instead.
                val cacheFile = downloadRemoteBundle(bundleSource) ?: return null
                // Load synchronously: on RN 0.85 bridgeless an async load executes the
                // bundle before TurboModule JSI bindings are installed, causing a fatal.
                JSBundleLoader.createFileLoader(cacheFile.absolutePath, bundleSource, true)
            }

            else -> {
                JSBundleLoader.createAssetLoader(context, "assets://$bundleSource", true)
            }
        }
    }

    private fun downloadRemoteBundle(bundleSource: String): File? {
        val cacheFile = File(context.cacheDir, "sandbox-remote-${bundleSource.hashCode()}.bundle")
        if (cacheFile.exists() && cacheFile.length() > 0L) {
            Log.d(TAG, "Reusing cached bundle '$bundleSource' (${cacheFile.length()} bytes)")
            return cacheFile
        }
        var downloadError: Exception? = null
        val worker =
            Thread {
                try {
                    val connection = URL(bundleSource).openConnection() as HttpURLConnection
                    connection.connectTimeout = REMOTE_BUNDLE_CONNECT_TIMEOUT_MS
                    connection.readTimeout = REMOTE_BUNDLE_READ_TIMEOUT_MS
                    try {
                        connection.inputStream.use { input ->
                            cacheFile.outputStream().use { output -> input.copyTo(output) }
                        }
                    } finally {
                        connection.disconnect()
                    }
                } catch (e: Exception) {
                    downloadError = e
                }
            }
        worker.start()
        worker.join(REMOTE_BUNDLE_DOWNLOAD_TIMEOUT_MS)
        if (downloadError != null || !cacheFile.exists() || cacheFile.length() == 0L) {
            cacheFile.delete()
            Log.e(TAG, "Failed to download remote bundle '$bundleSource'", downloadError)
            return null
        }
        Log.d(TAG, "Downloaded remote bundle '$bundleSource' (${cacheFile.length()} bytes)")
        return cacheFile
    }

    fun onJSIBindingsInstalled(stateHandle: Long) {
        jsiStateHandle = stateHandle
        // Store on the shared host so views that reuse this host can
        // deliver Host→JS messages through the same JSI state.
        if (origin.isNotEmpty()) {
            sharedHosts[origin]?.jsiStateHandle = stateHandle
        }
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
        UiThreadUtil.runOnUiThread {
            try {
                val view = sandboxView
                if (!hasOnMessageHandler || view == null || !view.isAttachedToWindow) {
                    synchronized(pendingHostMessages) {
                        pendingHostMessages.add(messageJson)
                    }
                    return@runOnUiThread
                }
                val data =
                    Arguments.createMap().apply {
                        putString("data", messageJson)
                    }
                view.emitOnMessage(data)
            } catch (e: Exception) {
                Log.e(TAG, "Error emitting onMessage: ${e.message}", e)
            }
        }
    }

    /**
     * Flush any messages that were buffered because the view wasn't ready
     * when they arrived (warm start timing). Called from the view manager
     * after the React Native child view is attached.
     */
    fun flushPendingHostMessages() {
        if (!hasOnMessageHandler) return
        val messages: List<String>
        synchronized(pendingHostMessages) {
            if (pendingHostMessages.isEmpty()) return
            messages = pendingHostMessages.toList()
            pendingHostMessages.clear()
        }
        UiThreadUtil.runOnUiThread {
            val view = sandboxView ?: return@runOnUiThread
            for (messageJson in messages) {
                try {
                    val data =
                        Arguments.createMap().apply {
                            putString("data", messageJson)
                        }
                    view.emitOnMessage(data)
                } catch (e: Exception) {
                    Log.e(TAG, "Error flushing pending message: ${e.message}", e)
                }
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
        if (surfaceId.isNotEmpty()) {
            delegateBySurfaceId.remove(surfaceId)
        }

        synchronized(pendingHostMessages) {
            pendingHostMessages.clear()
        }

        if (registryDelegateHandle != 0L) {
            SandboxJSIInstaller.nativeUnregisterDelegate(registryDelegateHandle)
            registryDelegateHandle = 0
        }

        // Only destroy the shared JSI state when this view owns the host AND
        // it's the last user AND the host is actually being destroyed (no TTL).
        // When TTL is active, the host stays alive and a new surface may reuse
        // the JSI state, so we must not tear it down.
        if (jsiStateHandle != 0L) {
            val isLastUser =
                if (origin.isNotEmpty()) {
                    val shared = sharedHosts[origin]
                    shared == null || (shared.refCount <= 1 && ownsReactHost)
                } else {
                    true
                }
            val hostBeingKeptAlive =
                if (origin.isNotEmpty()) {
                    val shared = sharedHosts[origin]
                    shared != null && shared.refCount <= 1 && shared.idleTTLMs > 0
                } else {
                    false
                }
            if (isLastUser && !hostBeingKeptAlive) {
                SandboxJSIInstaller.nativeDestroy(jsiStateHandle)
            } else if (ownsReactHost && !hostBeingKeptAlive) {
                SandboxJSIInstaller.nativeUnregisterStateDelegate(jsiStateHandle)
            }
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
                        val capturedOrigin = origin
                        val ttl = shared.idleTTLMs
                        if (ttl > 0) {
                            val gen = shared.destroyGeneration.incrementAndGet()
                            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                check(android.os.Looper.myLooper() == android.os.Looper.getMainLooper()) {
                                    "SharedReactHost destroy must run on the main thread"
                                }
                                val current = sharedHosts[capturedOrigin]
                                if (current != null && current.refCount <= 0 && current.destroyGeneration.get() == gen) {
                                    // Now actually destroy the JSI state that was kept alive
                                    if (current.jsiStateHandle != 0L) {
                                        SandboxJSIInstaller.nativeDestroy(current.jsiStateHandle)
                                        current.jsiStateHandle = 0
                                    }
                                    sharedHosts.remove(capturedOrigin)
                                    current.reactHost.onHostDestroy()
                                    current.reactHost.destroy("lazy sandbox cleanup", null)
                                }
                            }, ttl)
                        } else {
                            sharedHosts.remove(capturedOrigin)
                            host.onHostDestroy()
                            host.destroy("sandbox cleanup", null)
                        }
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

    /**
     * Injects __sandboxSurfaceId into the initialProperties Bundle so the
     * sandbox JS can pass it back through useSurfaceMessaging for per-surface routing.
     */
    private fun Bundle?.withSurfaceId(): Bundle {
        val bundle = this ?: Bundle()
        bundle.putString("__sandboxSurfaceId", surfaceId)
        return bundle
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
                Log.d(TAG, "Substitution target '$resolvedName' not found in any package for '$name'")
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
