#pragma once

#include <AppSpecJSI.h>

#include <map>
#include <mutex>
#include <string>

// #include "JsiValueBridgging.hpp"

namespace facebook::react {

class IPCTurboModule final : public NativeIPCTurboModuleCxxSpec<IPCTurboModule> {
public:
  IPCTurboModule(std::shared_ptr<CallInvoker> jsInvoker);

  // TODO: this call can be implicit but need agreement on callback function i.e. something like global.moduleHandlerCallback
  // For-the-Record:
  // 1. `T &` args not work        - codegen restriction
  // 2. `jsi::Value` args not work - codegen restriction
  void registerRuntime(
    jsi::Runtime& runtime,
    const jsi::String runtimeName,
    jsi::Function callback
  );

  // TODO: template to accept not only jsi::Object, but other data types like String, Symbol etc. TODO make pass for jsi::Value
  void sendToRuntime(
    jsi::Runtime& runtime,
    const jsi::String runtimeName,
    const jsi::Object value
  );

private:
  static std::map<std::string, std::pair<jsi::Runtime*, jsi::Function>> callbackMap_;
  static std::mutex mapMutex_;
};

} // namespace facebook::react
