#include "StubTurboModuleCxx.h"
#import <React/RCTLog.h>

namespace facebook {
namespace react {

StubTurboModuleCxx::StubTurboModuleCxx(const std::string &moduleName, std::shared_ptr<CallInvoker> jsInvoker)
    : TurboModule("StubTurboModuleCxx", jsInvoker), moduleName_(moduleName)
{
  logBlockedAccess("constructor");
}

jsi::Value StubTurboModuleCxx::get(jsi::Runtime &runtime, const jsi::PropNameID &propName)
{
  std::string methodName = propName.utf8(runtime);
  logBlockedAccess(methodName);
  return createStubFunction(runtime, methodName);
}

void StubTurboModuleCxx::logBlockedAccess(const std::string &methodName) const
{
  RCTLogWarn(
      @"[StubTurboModuleCxx] Blocked access to method '%s' on disallowed module '%s'. This module is blocked as unsafe, please add it to allowedTurboModules in SandboxReactNativeView.",
      methodName.c_str(),
      moduleName_.c_str());
}

jsi::Function StubTurboModuleCxx::createStubFunction(jsi::Runtime &runtime, const std::string &methodName) const
{
  return jsi::Function::createFromHostFunction(
      runtime,
      jsi::PropNameID::forAscii(runtime, methodName.c_str()),
      0,
      [this, methodName](
          jsi::Runtime &rt, const jsi::Value &thisVal, const jsi::Value *args, size_t count) -> jsi::Value {
        logBlockedAccess(methodName);
#if DEBUG
        auto errorMsg =
            [NSString stringWithFormat:@"Module '%s' is blocked. Method '%s' is not available in this sandbox.",
                                       this->moduleName_.c_str(),
                                       methodName.c_str()]
                .UTF8String;
        auto Promise = rt.global().getPropertyAsFunction(rt, "Promise");
        auto reject = Promise.getPropertyAsFunction(rt, "reject");
        auto Error = rt.global().getPropertyAsFunction(rt, "Error");
        auto error = Error.callAsConstructor(rt, jsi::String::createFromUtf8(rt, errorMsg));
        return reject.callWithThis(rt, Promise, error);
#else
        return jsi::Value::undefined();
#endif
      });
}

} // namespace react
} // namespace facebook