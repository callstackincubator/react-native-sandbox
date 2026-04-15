#pragma once

#include <string>
#include "ISandboxDelegate.h"

#ifdef __OBJC__
@class SandboxReactNativeDelegate;
#else
typedef struct objc_object SandboxReactNativeDelegate;
#endif

namespace rnsandbox {

/**
 * C++ wrapper for SandboxReactNativeDelegate that implements ISandboxDelegate.
 * This allows the C++ registry to work with Objective-C++ objects through
 * a proper C++ interface.
 *
 * The wrapped delegate pointer is non-owning. Call invalidate() before the
 * delegate is deallocated to prevent dangling pointer access.
 */
class SandboxDelegateWrapper : public ISandboxDelegate {
 public:
  explicit SandboxDelegateWrapper(SandboxReactNativeDelegate* delegate);

  ~SandboxDelegateWrapper() override = default;

  void invalidate() {
    delegate_ = nullptr;
  }

  void postMessage(const std::string& message) override;
  bool routeMessage(const std::string& message, const std::string& targetId)
      override;
  void setOrigin(const std::string& origin) override;
  void setAllowedOrigins(const std::set<std::string>& origins) override;
  void setAllowedTurboModules(const std::set<std::string>& modules) override;

 private:
  SandboxReactNativeDelegate* delegate_;
};

} // namespace rnsandbox
