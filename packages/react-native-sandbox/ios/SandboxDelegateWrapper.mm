#include "SandboxDelegateWrapper.h"
#import "SandboxReactNativeDelegate.h"

namespace facebook {
namespace react {

SandboxDelegateWrapper::SandboxDelegateWrapper(SandboxReactNativeDelegate *delegate) : delegate_(delegate)
{
  // Validate that delegate is not null
  if (!delegate_) {
    throw std::invalid_argument("SandboxReactNativeDelegate cannot be null");
  }
}

void SandboxDelegateWrapper::postMessage(const std::string &message)
{
  if (!delegate_)
    return;
  [delegate_ postMessage:message];
}

bool SandboxDelegateWrapper::routeMessage(const std::string &message, const std::string &targetId)
{
  if (!delegate_)
    return false;
  return [delegate_ routeMessage:message toSandbox:targetId];
}

void SandboxDelegateWrapper::setOrigin(const std::string &origin)
{
  if (!delegate_)
    return;
  [delegate_ setOrigin:origin];
}

void SandboxDelegateWrapper::setAllowedOrigins(const std::set<std::string> &origins)
{
  if (!delegate_)
    return;
  [delegate_ setAllowedOrigins:origins];
}

void SandboxDelegateWrapper::setAllowedTurboModules(const std::set<std::string> &modules)
{
  if (!delegate_)
    return;
  [delegate_ setAllowedTurboModules:modules];
}

} // namespace react
} // namespace facebook