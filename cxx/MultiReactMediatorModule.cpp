#include "MultiReactMediatorModule.hpp"

#include <stdexcept>
#include <utility>
#include <fmt/format.h>

#include "ReactLogger.hpp"

namespace facebook::react {

// Define static fields
std::map<std::string, std::pair<jsi::Runtime*, jsi::Function>> MultiReactMediatorModule::callbackMap_;
std::map<jsi::Runtime*, MultiReactMediatorModule*> MultiReactMediatorModule::runtimeToModuleMap_;
std::mutex MultiReactMediatorModule::mapMutex_;

constexpr std::string LOGTAG = "MultiReactMediator";

MultiReactMediatorModule::MultiReactMediatorModule(std::shared_ptr<CallInvoker> jsInvoker)
: NativeMultiReactMediatorCxxSpec(std::move(jsInvoker)) {
  logger::logDebug(LOGTAG, fmt::format("module={} constructor", static_cast<void*>(this)));

  jsInvoker_->invokeAsync([this](jsi::Runtime &rt) {
    // NOTE: it seems like race happens here
    // Error: getPropertyAsObject: property 'RN$AppRegistry' is undefined, expected an Object, js engine: hermes

    {
      std::lock_guard<std::mutex> lock(mapMutex_);
      runtimeToModuleMap_[&rt] = this;
    }

    jsi::Object appRegistry = rt.global()
          .getPropertyAsObject(rt, "RN$AppRegistry");

    jsi::Array appKeys = appRegistry
          .getPropertyAsFunction(rt, "getAppKeys")
          .call(rt)
          .asObject(rt)
          .asArray(rt);
    
    std::string componentName = appKeys.getValueAtIndex(rt, 1)
          .asString(rt)
          .utf8(rt);

    logger::logDebug(LOGTAG, fmt::format("module={} runtime={} componentName={} constructor's invokeAsync", static_cast<void*>(this) , static_cast<void*>(&rt), componentName));
  });
}

MultiReactMediatorModule::~MultiReactMediatorModule() {
  {
    std::lock_guard<std::mutex> lock(mapMutex_);
    std::erase_if(runtimeToModuleMap_, [this](const auto& pair) { return pair.second == this; });
  }logger::logDebug(LOGTAG, fmt::format("module={} destructor", static_cast<void*>(this)));
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

  runtimeToModuleMap_[targetRuntime]->jsInvoker_->invokeAsync([json, &callback](jsi::Runtime &rt) {
    jsi::String jsiJson = jsi::String::createFromAscii(rt, json);
    jsi::Value cloned = rt.global()
          .getPropertyAsObject(rt, "JSON")
          .getPropertyAsFunction(rt, "parse")
          .call(rt, jsiJson);
    callback.call(rt, { std::move(cloned) });
  });
}

} // namespace facebook::react



