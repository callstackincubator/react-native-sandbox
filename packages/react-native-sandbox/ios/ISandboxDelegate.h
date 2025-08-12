#pragma once

#include <memory>
#include <set>
#include <string>

namespace facebook {
namespace react {

/**
 * Interface for sandbox delegates that provides a clean abstraction
 * for sandbox functionality without React Native dependencies.
 *
 * This interface enables:
 * - Better testability (can be mocked without React Native)
 * - Cleaner separation of concerns
 * - Elimination of string conversions between std::string and NSString
 */
class ISandboxDelegate {
 public:
  virtual ~ISandboxDelegate() = default;

  /**
   * Posts a message to the JavaScript runtime.
   * @param message JSON-serialized message string
   */
  virtual void postMessage(const std::string& message) = 0;

  /**
   * Routes a message to a specific sandbox delegate.
   * @param message The message to route
   * @param targetId The ID of the target sandbox
   * @return true if the message was successfully routed, false otherwise
   */
  virtual bool routeMessage(
      const std::string& message,
      const std::string& targetId) = 0;

  /**
   * Sets the origin identifier for this sandbox.
   * @param origin Unique identifier for the sandbox
   */
  virtual void setOrigin(const std::string& origin) = 0;

  /**
   * Sets the list of allowed origins for this sandbox instance.
   * Only sandboxes with origins in this list can send messages to this sandbox.
   * @param origins Set of allowed origin strings
   */
  virtual void setAllowedOrigins(const std::set<std::string>& origins) = 0;

  /**
   * Sets the list of allowed TurboModules for this sandbox instance.
   * Only modules in this list will be accessible to the JavaScript runtime.
   * @param modules Set of allowed TurboModule names
   */
  virtual void setAllowedTurboModules(const std::set<std::string>& modules) = 0;
};

} // namespace react
} // namespace facebook