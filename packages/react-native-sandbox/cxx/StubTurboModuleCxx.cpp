#include "StubTurboModuleCxx.h"
#include "SandboxLog.h"

namespace rnsandbox {

StubTurboModuleCxx::StubTurboModuleCxx(
    const std::string& moduleName,
    std::shared_ptr<facebook::react::CallInvoker> jsInvoker)
    : facebook::react::TurboModule("StubTurboModuleCxx", jsInvoker),
      moduleName_(moduleName) {
  logBlockedAccess("constructor");
}

facebook::jsi::Value StubTurboModuleCxx::get(
    facebook::jsi::Runtime& runtime,
    const facebook::jsi::PropNameID& propName) {
  std::string methodName = propName.utf8(runtime);
  logBlockedAccess(methodName);
  return createStubFunction(runtime, methodName);
}

void StubTurboModuleCxx::logBlockedAccess(const std::string& methodName) const {
  SANDBOX_LOG_WARN(
      "[StubTurboModuleCxx] Blocked access to method '%s' on disallowed "
      "module '%s'.",
      methodName.c_str(),
      moduleName_.c_str());
}

facebook::jsi::Function StubTurboModuleCxx::createStubFunction(
    facebook::jsi::Runtime& runtime,
    const std::string& methodName) const {
  return facebook::jsi::Function::createFromHostFunction(
      runtime,
      facebook::jsi::PropNameID::forAscii(runtime, methodName.c_str()),
      0,
      [moduleName = moduleName_, methodName](
          facebook::jsi::Runtime&,
          const facebook::jsi::Value&,
          const facebook::jsi::Value*,
          size_t) -> facebook::jsi::Value {
        SANDBOX_LOG_WARN(
            "[StubTurboModuleCxx] Method call '%s' blocked on module '%s'.",
            methodName.c_str(),
            moduleName.c_str());
        return facebook::jsi::Value::undefined();
      });
}

} // namespace rnsandbox
