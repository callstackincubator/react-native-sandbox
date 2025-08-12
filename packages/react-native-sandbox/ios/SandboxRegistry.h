#pragma once

#include <map>
#include <memory>
#include <mutex>
#include <set>
#include <string>
#include <vector>
#include "ISandboxDelegate.h"

namespace facebook {
namespace react {

/**
 * A thread-safe singleton registry for managing sandbox delegates across
 * multiple instances. This C++ implementation provides better performance and
 * testability compared to the Objective-C++ version by eliminating string
 * conversions and React Native dependencies.
 *
 * The registry is type-agnostic and works with any delegate type that
 * implements the ISandboxDelegate interface.
 */
class SandboxRegistry {
 public:
  /**
   * Returns the shared singleton instance of the registry.
   * @return Reference to the shared registry instance
   */
  static SandboxRegistry& getInstance();

  /**
   * Registers a delegate with the specified origin and allowed origins.
   * @param origin Unique identifier for the sandbox
   * @param delegate The delegate instance to register (must implement
   * ISandboxDelegate)
   * @param allowedOrigins Vector of sandbox origins that are allowed to send
   * messages to this sandbox. If empty, no other sandboxes will be allowed to
   * send messages (except 'host'). Re-registering with new allowedOrigins will
   * override previous settings.
   */
  void registerSandbox(
      const std::string& origin,
      std::shared_ptr<ISandboxDelegate> delegate,
      const std::set<std::string>& allowedOrigins);

  /**
   * Unregisters a delegate by origin.
   * @param origin The origin of the sandbox to unregister
   */
  void unregister(const std::string& origin);

  /**
   * Finds a delegate by origin.
   * @param origin The origin of the sandbox to find
   * @return The registered delegate, or nullptr if not found
   */
  std::shared_ptr<ISandboxDelegate> find(const std::string& origin);

  /**
   * Checks if communication is permitted from one sandbox to another.
   * @param sourceOrigin The origin of the sandbox attempting to send a message
   * @param targetOrigin The origin of the sandbox that would receive the
   * message
   * @return true if the source sandbox is permitted to send messages to the
   * target, false otherwise
   */
  bool isPermittedFrom(
      const std::string& sourceOrigin,
      const std::string& targetOrigin);

  /**
   * Resets the registry (clears all sandboxes and permissions).
   * This is primarily used for testing.
   */
  void reset();

 private:
  // Private constructor for singleton pattern
  SandboxRegistry() = default;

  // Disable copy constructor and assignment operator
  SandboxRegistry(const SandboxRegistry&) = delete;
  SandboxRegistry& operator=(const SandboxRegistry&) = delete;

  // Registry storage
  std::map<std::string, std::shared_ptr<ISandboxDelegate>> sandboxRegistry_;
  std::map<std::string, std::set<std::string>> allowedOrigins_;

  // Thread safety
  mutable std::recursive_mutex registryMutex_;
};

} // namespace react
} // namespace facebook