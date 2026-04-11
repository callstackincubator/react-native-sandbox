#pragma once

#ifdef __cplusplus

#include <string>

namespace rnsandbox {

/**
 * Context information provided to sandbox-aware TurboModules.
 * Contains the sandbox identity and module mapping details needed
 * for scoping module behavior per sandbox instance.
 */
struct SandboxContext {
  /** The origin identifier of the sandbox instance */
  std::string origin;

  /** The module name that sandbox JS code requested (e.g. "RNCAsyncStorage") */
  std::string requestedModuleName;

  /** The actual module name that was resolved via substitution (e.g.
   * "SandboxedAsyncStorage") */
  std::string resolvedModuleName;
};

/**
 * Interface for TurboModules that need sandbox-specific configuration.
 *
 * When a TurboModule is provided as a substitution in the sandbox,
 * the sandbox delegate will check if the module implements this interface
 * and call configureSandbox() with the relevant context.
 *
 * This enables modules to scope their behavior per sandbox origin,
 * e.g. sandboxing file system access to a per-origin directory or
 * isolating AsyncStorage keys by origin.
 *
 * Usage:
 * @code
 * class SandboxedAsyncStorage : public TurboModule, public ISandboxAwareModule
 * { public: void configureSandbox(const SandboxContext& context) override {
 *     // Scope storage to this sandbox's origin
 *     storagePrefix_ = context.origin;
 *   }
 * };
 * @endcode
 */
class ISandboxAwareModule {
 public:
  virtual ~ISandboxAwareModule() = default;

  /**
   * Called by the sandbox delegate after module instantiation to provide
   * sandbox-specific context. Implementations should use this to scope
   * their behavior (storage, file paths, etc.) to the given sandbox.
   *
   * @param context The sandbox context containing origin and module mapping
   * info
   */
  virtual void configureSandbox(const SandboxContext& context) = 0;
};

} // namespace rnsandbox

#endif // __cplusplus
