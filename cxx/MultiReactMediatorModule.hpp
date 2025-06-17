#pragma once

#include <AppSpecJSI.h>

#include <map>
#include <mutex>
#include <string>

namespace facebook::react {

class MultiReactMediatorModule final : public NativeMultiReactMediatorCxxSpec<MultiReactMediatorModule> {
public:
  MultiReactMediatorModule(std::shared_ptr<CallInvoker> jsInvoker);

  void registerRuntime(
    jsi::Runtime& runtime,
    const jsi::String origin,
    jsi::Function callback
  );

  void postMessage(
    jsi::Runtime& runtime,
    const jsi::String targetOrigin,
    const jsi::Object message
  );

private:
  static std::map<std::string, std::pair<jsi::Runtime*, jsi::Function>> callbackMap_;
  static std::mutex mapMutex_;
};

} // namespace facebook::react
