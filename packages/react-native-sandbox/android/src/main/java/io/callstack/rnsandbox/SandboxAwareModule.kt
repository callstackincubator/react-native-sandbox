package io.callstack.rnsandbox

/**
 * Interface for native modules that need sandbox-specific configuration.
 *
 * When a native module is provided as a substitution in the sandbox,
 * the sandbox delegate checks if it implements this interface and calls
 * [configureSandbox] with context about the sandbox instance.
 *
 * This enables modules to scope their behavior per sandbox origin,
 * e.g. sandboxing file system access to a per-origin directory or
 * isolating AsyncStorage keys by origin.
 */
interface SandboxAwareModule {
    /**
     * Called by the sandbox delegate after module instantiation to provide
     * sandbox-specific context.
     *
     * @param origin The sandbox origin identifier
     * @param requestedName The module name sandbox JS code requested
     * @param resolvedName The actual module name that was resolved
     */
    fun configureSandbox(
        origin: String,
        requestedName: String,
        resolvedName: String,
    )
}
