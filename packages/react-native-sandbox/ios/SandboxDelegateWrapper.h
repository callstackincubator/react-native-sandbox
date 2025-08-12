#pragma once

#include <memory>
#include <string>
#include <vector>
#include "ISandboxDelegate.h"

// Forward declaration to avoid including Objective-C headers in C++ interface
#ifdef __OBJC__
@class SandboxReactNativeDelegate;
#else
typedef struct objc_object SandboxReactNativeDelegate;
#endif

namespace facebook {
namespace react {

/**
 * C++ wrapper for SandboxReactNativeDelegate that implements ISandboxDelegate.
 * This allows the C++ registry to work with Objective-C++ objects through
 * a proper C++ interface.
 */
class SandboxDelegateWrapper : public ISandboxDelegate {
 public:
  /**
   * Creates a wrapper around the given Objective-C++ delegate.
   * @param delegate The Objective-C++ delegate to wrap (must not be null)
   */
  explicit SandboxDelegateWrapper(SandboxReactNativeDelegate* delegate);

  /**
   * Destructor - does not delete the wrapped delegate
   */
  ~SandboxDelegateWrapper() override = default;

  // ISandboxDelegate implementation
  void postMessage(const std::string& message) override;
  bool routeMessage(const std::string& message, const std::string& targetId)
      override;
  void setOrigin(const std::string& origin) override;
  void setAllowedOrigins(const std::set<std::string>& origins) override;
  void setAllowedTurboModules(const std::set<std::string>& modules) override;

 private:
  // Non-owning pointer to the Objective-C++ delegate
  SandboxReactNativeDelegate* delegate_;
};

} // namespace react
} // namespace facebook