#include "MultiReactMediatorModule.hpp"

#include <stdexcept>
#include <utility>
#include <fmt/format.h>

#include "ReactLogger.hpp"

namespace facebook::react {

// Define static fields
std::map<std::string, std::pair<jsi::Runtime*, jsi::Function>> MultiReactMediatorModule::callbackMap_;
std::mutex MultiReactMediatorModule::mapMutex_;

constexpr std::string LOGTAG = "MultiReactMediator";

MultiReactMediatorModule::MultiReactMediatorModule(std::shared_ptr<CallInvoker> jsInvoker)
: NativeMultiReactMediatorCxxSpec(std::move(jsInvoker)) {
  logger::logDebug(LOGTAG, fmt::format("module={} constructor", static_cast<void*>(this)));

  jsInvoker_->invokeAsync([this](jsi::Runtime &rt) {
    std::string componentName = rt.global()
          .getPropertyAsObject(rt, "RN$AppRegistry")
          .getPropertyAsFunction(rt, "getAppKeys")
          .call(rt)
          .asObject(rt)
          .asArray(rt)
          .getValueAtIndex(rt, 1)
          .asString(rt)
          .utf8(rt);
    logger::logDebug(LOGTAG, fmt::format("module={} runtime={} componentName={}", static_cast<void*>(this) , static_cast<void*>(&rt), componentName));
  });
}

void MultiReactMediatorModule::registerRuntime(
  jsi::Runtime& rt,
  const jsi::String origin,
  jsi::Function callback
) {
  std::lock_guard<std::mutex> lock(mapMutex_);
  std::string runtimeName = origin.utf8(rt);

  logger::logDebug(LOGTAG, fmt::format("module={} runtime={} registerRuntime {}", static_cast<void*>(this) , static_cast<void*>(&rt), runtimeName));

  callbackMap_.emplace(std::move(runtimeName), std::make_pair(&rt, std::move(callback)));
}

void MultiReactMediatorModule::postMessage(
  jsi::Runtime& sourceRuntime,
  const jsi::String targetOrigin,
  const jsi::Object message
) {
  std::lock_guard<std::mutex> lock(mapMutex_);
  std::string runtimeName = targetOrigin.utf8(sourceRuntime);
  auto it = callbackMap_.find(runtimeName);
  if (it == callbackMap_.end()) {
    throw jsi::JSError(sourceRuntime, fmt::format("sendToRuntime: No callback registered for runtime '{}'", runtimeName));
  }

  jsi::Runtime* targetRuntime = it->second.first;
  jsi::Function& callback = it->second.second;

  logger::logDebug(LOGTAG, fmt::format("module={} runtime={} postMessage to {}", static_cast<void*>(this) , static_cast<void*>(&sourceRuntime), runtimeName));

  if (targetRuntime == &sourceRuntime) {
    // TODO: no clone need print some warn
    jsi::Value cloned { *targetRuntime, message };
    callback.call(*targetRuntime, std::move(cloned));
    return;
  }

  // jsi::Object or jsi::Array
  std::string json = sourceRuntime.global()
        .getPropertyAsObject(sourceRuntime, "JSON")
        .getPropertyAsFunction(sourceRuntime, "stringify")
        .call(sourceRuntime, message)
        .asString(sourceRuntime)
        .utf8(sourceRuntime);
  jsi::String jsiJson = jsi::String::createFromAscii(*targetRuntime, json);
  jsi::Value cloned = targetRuntime->global().getPropertyAsObject(*targetRuntime, "JSON").getPropertyAsFunction(*targetRuntime, "parse").call(*targetRuntime, jsiJson);

  // Example: String
  // std::string valueStr = value.utf8(runtime);
  // jsi::Value cloned { *targetRuntime, jsi::String::createFromAscii(runtime, valueStr) };

  // Example: BigInt
  // int64_t valueInt64 = value.getInt64(runtime);
  // jsi::Value cloned { *targetRuntime, jsi::BigInt::fromInt64(runtime, valueInt64) };

  // Example: ArrayBuffer
  //  const jsi::ArrayBuffer& buffer = value.getArrayBuffer(runtime);
  //  class SimpleBuffer : public jsi::MutableBuffer {
  //   public:
  //    explicit SimpleBuffer(size_t size) : size_(size), data_(new uint8_t[size]) {}
  //    ~SimpleBuffer() override { delete[] data_; }
  //    size_t size() const override { return size_; }
  //    uint8_t* data() override { return data_; }
  //   private:
  //    size_t size_;
  //    uint8_t* data_;
  //  };
  //  auto newBuffer = std::make_shared<SimpleBuffer>(buffer.size(runtime));
  //  std::memcpy(newBuffer->data(), buffer.data(runtime), buffer.size(runtime));
  //  jsi::Value cloned { *targetRuntime, jsi::ArrayBuffer(*targetRuntime, std::move(newBuffer)) };

  // Function - not supported
  // Symbol - not supported

  callback.call(*targetRuntime, { std::move(cloned) });
}

} // namespace facebook::react



