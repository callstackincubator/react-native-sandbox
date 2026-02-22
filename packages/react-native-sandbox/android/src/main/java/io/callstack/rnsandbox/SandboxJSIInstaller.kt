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
}
