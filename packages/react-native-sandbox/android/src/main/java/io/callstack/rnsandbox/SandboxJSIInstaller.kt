package io.callstack.rnsandbox

/**
 * JNI bridge for installing JSI globals (postMessage, setOnMessage) into a
 * sandboxed React Native runtime. Mirrors the iOS SandboxReactNativeDelegate's
 * JSI setup via hostDidStart:.
 */
object SandboxJSIInstaller {
    init {
        System.loadLibrary("rnsandbox")
    }

    /**
     * Installs postMessage/setOnMessage globals into the JS runtime.
     * Must be called on the JS thread.
     *
     * @param runtimePtr Raw pointer to jsi::Runtime (from JavaScriptContextHolder.get())
     * @param delegate The delegate that handles messages from JS
     * @return A state handle for subsequent postMessage/destroy calls, or 0 on failure
     */
    @JvmStatic
    external fun nativeInstall(
        runtimePtr: Long,
        delegate: SandboxReactNativeDelegate,
    ): Long

    /**
     * Delivers a JSON message to the sandbox's JS onMessage callback.
     * Must be called on the JS thread.
     *
     * @param stateHandle Handle returned by nativeInstall
     * @param message JSON-serialized message string
     */
    @JvmStatic
    external fun nativePostMessage(
        stateHandle: Long,
        message: String,
    )

    /**
     * Cleans up JSI state for a sandbox. Safe to call from any thread.
     *
     * @param stateHandle Handle returned by nativeInstall
     */
    @JvmStatic
    external fun nativeDestroy(stateHandle: Long)

    /**
     * Installs the error handler into the JS runtime. Must be called on the
     * JS thread after the bundle has loaded (when ErrorUtils is available).
     *
     * @param stateHandle Handle returned by nativeInstall
     */
    @JvmStatic
    external fun nativeInstallErrorHandler(stateHandle: Long)

    /**
     * Registers an additional delegate for an origin in the C++ SandboxRegistry.
     * Used when a second view shares an existing ReactHost (same origin) and
     * needs its own delegate to receive messages and errors.
     *
     * @param origin The sandbox origin string
     * @param delegate The delegate that handles messages/errors for this view
     * @return An opaque handle that must be passed to nativeUnregisterDelegate on cleanup
     */
    @JvmStatic
    external fun nativeRegisterDelegate(
        origin: String,
        delegate: SandboxReactNativeDelegate,
    ): Long

    /**
     * Unregisters a delegate previously registered via nativeRegisterDelegate.
     *
     * @param handle The handle returned by nativeRegisterDelegate
     */
    @JvmStatic
    external fun nativeUnregisterDelegate(handle: Long)

    /**
     * Unregisters the delegate associated with a JSI state handle from the
     * C++ SandboxRegistry without destroying the state. Used when the first
     * view for an origin is removed but other views still share the host.
     *
     * @param stateHandle Handle returned by nativeInstall
     */
    @JvmStatic
    external fun nativeUnregisterStateDelegate(stateHandle: Long)

    /**
     * Updates the allowedOrigins for an origin in the C++ SandboxRegistry.
     * Called when the allowedOrigins prop changes on a sandbox view.
     *
     * @param origin The sandbox origin string
     * @param allowedOrigins Array of origin strings permitted to send messages to this origin
     */
    @JvmStatic
    external fun nativeUpdateAllowedOrigins(
        origin: String,
        allowedOrigins: Array<String>,
    )
}
