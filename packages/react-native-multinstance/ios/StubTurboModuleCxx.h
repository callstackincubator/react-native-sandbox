#pragma once

#ifdef __cplusplus

#include <ReactCommon/TurboModule.h>
#include <jsi/jsi.h>
#include <memory>
#include <string>

namespace facebook {
namespace react {

/**
 * A C++ TurboModule stub implementation that intercepts all method calls for blocked modules.
 * This prevents crashes when sandbox code tries to access disallowed modules while logging warnings.
 */
class StubTurboModuleCxx : public TurboModule {
 public:
  /**
   * Creates a stub for the specified module name
   * @param moduleName The name of the blocked module
   * @param jsInvoker The JavaScript invoker for communication
   */
  StubTurboModuleCxx(const std::string& moduleName, std::shared_ptr<CallInvoker> jsInvoker);
  
  /**
   * Intercepts all method calls and returns safe default values
   * This is the main method that gets called for any TurboModule method invocation
   */
  jsi::Value get(jsi::Runtime& runtime, const jsi::PropNameID& propName) override;

 private:
  std::string moduleName_;
  
  /**
   * Logs a warning message about the blocked module access
   */
  void logBlockedAccess(const std::string& methodName) const;
  
  /**
   * Creates a stub function that logs warnings and returns safe values
   */
  jsi::Function createStubFunction(jsi::Runtime& runtime, const std::string& methodName) const;
};

} // namespace react
} // namespace facebook

#endif // __cplusplus 