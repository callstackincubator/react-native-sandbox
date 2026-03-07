#pragma once

#ifdef __cplusplus

#include <ReactCommon/TurboModule.h>
#include <jsi/jsi.h>
#include <memory>
#include <string>

namespace rnsandbox {

class StubTurboModuleCxx : public facebook::react::TurboModule {
 public:
  StubTurboModuleCxx(
      const std::string& moduleName,
      std::shared_ptr<facebook::react::CallInvoker> jsInvoker);

  facebook::jsi::Value get(
      facebook::jsi::Runtime& runtime,
      const facebook::jsi::PropNameID& propName) override;

 private:
  std::string moduleName_;

  void logBlockedAccess(const std::string& methodName) const;

  facebook::jsi::Function createStubFunction(
      facebook::jsi::Runtime& runtime,
      const std::string& methodName) const;
};

} // namespace rnsandbox

#endif // __cplusplus
