#include "StubTurboModuleCxx.h"
#import <React/RCTLog.h>

namespace facebook {
namespace react {

StubTurboModuleCxx::StubTurboModuleCxx(const std::string& moduleName, std::shared_ptr<CallInvoker> jsInvoker)
    : TurboModule("StubTurboModuleCxx", jsInvoker), moduleName_(moduleName) {
  logBlockedAccess("constructor");
}

jsi::Value StubTurboModuleCxx::get(jsi::Runtime& runtime, const jsi::PropNameID& propName) {
  // Get the property name as a string
  std::string methodName = propName.utf8(runtime);
  
  // Log the blocked access attempt
  logBlockedAccess(methodName);
  
  // Return a stub function that will handle any method calls
  return createStubFunction(runtime, methodName);
}

void StubTurboModuleCxx::logBlockedAccess(const std::string& methodName) const {
  RCTLogWarn(@"[StubTurboModuleCxx] Blocked access to method '%s' on disallowed module '%s'. This module is blocked as unsafe, please add it to allowedTurboModules in SandboxReactNativeView.", 
             methodName.c_str(), moduleName_.c_str());
}

jsi::Function StubTurboModuleCxx::createStubFunction(jsi::Runtime& runtime, const std::string& methodName) const {
  return jsi::Function::createFromHostFunction(
    runtime,
    jsi::PropNameID::forAscii(runtime, methodName.c_str()),
    0, // number of parameters - we accept any number
    [this, methodName](jsi::Runtime& rt, const jsi::Value& thisVal, const jsi::Value* args, size_t count) -> jsi::Value {
      // Log the method call attempt using React Native API
      RCTLogWarn(@"[StubTurboModuleCxx] Method call '%s' blocked on module '%s'. This module is blocked as unsafe, please add it to allowedTurboModules in SandboxReactNativeView.", 
                 methodName.c_str(), this->moduleName_.c_str());
      
      // Fail fast - just return undefined for all cases
      return jsi::Value::undefined();
    }
  );
}

} // namespace react
} // namespace facebook 