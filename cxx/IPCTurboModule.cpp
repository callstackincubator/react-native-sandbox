#include "IPCTurboModule.hpp"

#include <stdexcept>
#include <utility>

#include "ReactLogger.hpp"

namespace facebook::react {

// Define static fields
std::map<std::string, std::pair<jsi::Runtime*, jsi::Function>> IPCTurboModule::callbackMap_;
std::mutex IPCTurboModule::mapMutex_;

IPCTurboModule::IPCTurboModule(std::shared_ptr<CallInvoker> jsInvoker)
: NativeIPCTurboModuleCxxSpec(std::move(jsInvoker)) {
  logger::logDebug("IPCTurboModule", "module=" + logger::pointerToString(this) + " constructor");

  jsInvoker_->invokeAsync([this](jsi::Runtime &rt) {
    std::string componentName = rt.global()
          .getPropertyAsObject(rt, "RN$AppRegistry")
          .getPropertyAsFunction(rt, "getAppKeys")
          .call(rt)
          .asObject(rt)
          .asArray(rt)
          .getValueAtIndex(rt, 2)
          .asString(rt)
          .utf8(rt);
    logger::logDebug("IPCTurboModule", "module=" + logger::pointerToString(this) + " componentName=" + componentName);
  });
}

void IPCTurboModule::registerRuntime(
  jsi::Runtime& runtime,
  const jsi::String runtimeName,
  jsi::Function callback
) {
  std::lock_guard<std::mutex> lock(mapMutex_);
  std::string runtimeNameStr = runtimeName.utf8(runtime);
  logger::logDebug("IPCTurboModule", "module=" + logger::pointerToString(this) + " registerRuntime (" + runtimeNameStr + ")");

  callbackMap_.emplace(std::move(runtimeNameStr), std::make_pair(&runtime, std::move(callback)));
}

void IPCTurboModule::sendToRuntime(
  jsi::Runtime& runtime,
  const jsi::String runtimeName,
  const jsi::Object value
) {
  std::lock_guard<std::mutex> lock(mapMutex_);
  std::string runtimeNameStr = runtimeName.utf8(runtime);
  auto it = callbackMap_.find(runtimeNameStr);
  if (it == callbackMap_.end()) {
    throw jsi::JSError(runtime, "sendToRuntime: No callback registered for runtime '" + runtimeNameStr + "'");
  }

  jsi::Runtime* targetRuntime = it->second.first;
  jsi::Function& callback = it->second.second;

  logger::logDebug("IPCTurboModule", "module=" + logger::pointerToString(this) + " sendToRuntime (" + runtimeNameStr + ")");

  if (targetRuntime == &runtime) {
    // TODO: no clone need print some warn
    jsi::Value cloned { *targetRuntime, value };
    callback.call(*targetRuntime, std::move(cloned));
    return;
  }

  // jsi::Object or jsi::Array
  std::string json = runtime.global()
        .getPropertyAsObject(runtime, "JSON")
        .getPropertyAsFunction(runtime, "stringify")
        .call(runtime, value)
        .asString(runtime)
        .utf8(runtime);
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



