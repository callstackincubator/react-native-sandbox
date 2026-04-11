#include "StubTurboModuleCxx.h"
#include "SandboxLog.h"

namespace rnsandbox {

StubTurboModuleCxx::StubTurboModuleCxx(
    const std::string& moduleName,
    std::shared_ptr<facebook::react::CallInvoker> jsInvoker)
    : facebook::react::TurboModule("StubTurboModuleCxx", jsInvoker),
      moduleName_(moduleName) {
#if DEBUG
  logBlockedAccess("constructor");
#endif
}

facebook::jsi::Value StubTurboModuleCxx::get(
    facebook::jsi::Runtime& runtime,
    const facebook::jsi::PropNameID& propName) {
  std::string methodName = propName.utf8(runtime);
#if DEBUG
  logBlockedAccess(methodName);
#endif
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
          facebook::jsi::Runtime& rt,
          const facebook::jsi::Value&,
          const facebook::jsi::Value*,
          size_t) -> facebook::jsi::Value {
#if DEBUG
        SANDBOX_LOG_WARN(
            "[StubTurboModuleCxx] Method call '%s' blocked on module '%s'.",
            methodName.c_str(),
            moduleName.c_str());

        auto errorMsg = std::string("Module '") + moduleName +
            "' is blocked. Method '" + methodName +
            "' is not available in this sandbox.";
        auto Promise = rt.global().getPropertyAsFunction(rt, "Promise");
        auto reject = Promise.getPropertyAsFunction(rt, "reject");
        auto Error = rt.global().getPropertyAsFunction(rt, "Error");
        auto error = Error.callAsConstructor(
            rt, facebook::jsi::String::createFromUtf8(rt, errorMsg));
        return reject.callWithThis(rt, Promise, error);
#else
        return facebook::jsi::Value::undefined();
#endif
      });
}

} // namespace rnsandbox
