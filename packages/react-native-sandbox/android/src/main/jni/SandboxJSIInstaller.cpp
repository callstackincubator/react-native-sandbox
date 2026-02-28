#include "SandboxBindingsInstaller.h"

#include <android/log.h>
#include <fbjni/fbjni.h>
#include <jni.h>
#include <jsi/jsi.h>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

#define LOG_TAG "SandboxJSI"
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace jsi = facebook::jsi;

static JavaVM* gJavaVM = nullptr;

struct SandboxJSIState {
  jsi::Runtime* runtime = nullptr;
  std::shared_ptr<jsi::Function> onMessageCallback;
  std::vector<std::string> pendingMessages;
  std::mutex mutex;
};

static std::mutex gRegistryMutex;
static std::unordered_map<jlong, std::shared_ptr<SandboxJSIState>> gStates;

static JNIEnv* getJNIEnv() {
  JNIEnv* env = nullptr;
  if (gJavaVM) {
    gJavaVM->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    if (!env) {
      gJavaVM->AttachCurrentThread(&env, nullptr);
    }
  }
  return env;
}

static std::string safeGetStringProperty(
    jsi::Runtime& rt,
    const jsi::Object& obj,
    const char* key) {
  if (!obj.hasProperty(rt, key))
    return "";
  jsi::Value value = obj.getProperty(rt, key);
  return value.isString() ? value.getString(rt).utf8(rt) : "";
}

static void
stubJsiFunction(jsi::Runtime& runtime, jsi::Object& object, const char* name) {
  object.setProperty(
      runtime,
      name,
      jsi::Function::createFromHostFunction(
          runtime,
          jsi::PropNameID::forUtf8(runtime, name),
          1,
          [](auto&, const auto&, const auto*, size_t) {
            return jsi::Value::undefined();
          }));
}

static void setupErrorHandler(
    jsi::Runtime& runtime,
    jobject globalDelegateRef) {
  jsi::Object global = runtime.global();
  jsi::Value errorUtilsVal = global.getProperty(runtime, "ErrorUtils");
  if (!errorUtilsVal.isObject())
    return;

  jsi::Object errorUtils = errorUtilsVal.asObject(runtime);

  auto originalHandler = std::make_shared<jsi::Value>(
      errorUtils.getProperty(runtime, "getGlobalHandler")
          .asObject(runtime)
          .asFunction(runtime)
          .call(runtime));

  auto handlerFunc = jsi::Function::createFromHostFunction(
      runtime,
      jsi::PropNameID::forAscii(runtime, "sandboxGlobalErrorHandler"),
      2,
      [globalDelegateRef, originalHandler = std::move(originalHandler)](
          jsi::Runtime& rt,
          const jsi::Value&,
          const jsi::Value* args,
          size_t count) -> jsi::Value {
        if (count < 2)
          return jsi::Value::undefined();

        JNIEnv* jniEnv = getJNIEnv();
        if (!jniEnv)
          return jsi::Value::undefined();

        jclass cls = jniEnv->GetObjectClass(globalDelegateRef);
        jfieldID hasHandlerField =
            jniEnv->GetFieldID(cls, "hasOnErrorHandler", "Z");
        jboolean hasHandler =
            jniEnv->GetBooleanField(globalDelegateRef, hasHandlerField);

        if (hasHandler) {
          const jsi::Object& error = args[0].asObject(rt);
          bool isFatal = args[1].getBool();
          std::string name = safeGetStringProperty(rt, error, "name");
          std::string message = safeGetStringProperty(rt, error, "message");
          std::string stack = safeGetStringProperty(rt, error, "stack");

          jmethodID emitMethod = jniEnv->GetMethodID(
              cls,
              "emitOnErrorFromJS",
              "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Z)V");
          jstring jName = jniEnv->NewStringUTF(name.c_str());
          jstring jMsg = jniEnv->NewStringUTF(message.c_str());
          jstring jStack = jniEnv->NewStringUTF(stack.c_str());
          jniEnv->CallVoidMethod(
              globalDelegateRef,
              emitMethod,
              jName,
              jMsg,
              jStack,
              (jboolean)isFatal);
          jniEnv->DeleteLocalRef(jName);
          jniEnv->DeleteLocalRef(jMsg);
          jniEnv->DeleteLocalRef(jStack);
        } else if (
            originalHandler->isObject() &&
            originalHandler->asObject(rt).isFunction(rt)) {
          originalHandler->asObject(rt).asFunction(rt).call(rt, args, count);
        }

        jniEnv->DeleteLocalRef(cls);
        return jsi::Value::undefined();
      });

  jsi::Function setHandler = errorUtils.getProperty(runtime, "setGlobalHandler")
                                 .asObject(runtime)
                                 .asFunction(runtime);
  setHandler.call(runtime, std::move(handlerFunc));
  stubJsiFunction(runtime, errorUtils, "setGlobalHandler");
}

// Shared JSI installation logic used by both the BindingsInstaller path
// (pre-bundle) and the legacy nativeInstall JNI path (post-bundle fallback).
jlong installSandboxJSIBindings(
    jsi::Runtime& runtime,
    JNIEnv* env,
    jobject delegateRef) {
  auto state = std::make_shared<SandboxJSIState>();
  state->runtime = &runtime;

  jlong stateHandle = reinterpret_cast<jlong>(state.get());
  {
    std::lock_guard<std::mutex> lock(gRegistryMutex);
    gStates[stateHandle] = state;
  }

  jobject globalDelegateRef = env->NewGlobalRef(delegateRef);

  auto postMessageFn = jsi::Function::createFromHostFunction(
      runtime,
      jsi::PropNameID::forAscii(runtime, "postMessage"),
      2,
      [globalDelegateRef](
          jsi::Runtime& rt,
          const jsi::Value&,
          const jsi::Value* args,
          size_t count) -> jsi::Value {
        if (count < 1 || count > 2) {
          throw jsi::JSError(
              rt,
              "postMessage(message, targetOrigin?): expected 1 or 2 arguments");
        }
        if (!args[0].isObject()) {
          throw jsi::JSError(
              rt, "postMessage: first argument must be an object");
        }

        jsi::Object jsonObj = rt.global().getPropertyAsObject(rt, "JSON");
        jsi::Function stringify =
            jsonObj.getPropertyAsFunction(rt, "stringify");
        std::string messageJson =
            stringify.call(rt, args[0]).getString(rt).utf8(rt);

        JNIEnv* jniEnv = getJNIEnv();
        if (!jniEnv)
          return jsi::Value::undefined();

        if (count == 2 && !args[1].isNull() && !args[1].isUndefined()) {
          if (!args[1].isString()) {
            throw jsi::JSError(
                rt, "postMessage: targetOrigin must be a string");
          }
          std::string targetOrigin = args[1].getString(rt).utf8(rt);
          jclass cls = jniEnv->GetObjectClass(globalDelegateRef);
          jmethodID mid = jniEnv->GetMethodID(
              cls,
              "routeMessageFromJS",
              "(Ljava/lang/String;Ljava/lang/String;)Z");
          jstring jMsg = jniEnv->NewStringUTF(messageJson.c_str());
          jstring jTarget = jniEnv->NewStringUTF(targetOrigin.c_str());
          jniEnv->CallBooleanMethod(globalDelegateRef, mid, jMsg, jTarget);
          jniEnv->DeleteLocalRef(jMsg);
          jniEnv->DeleteLocalRef(jTarget);
          jniEnv->DeleteLocalRef(cls);
        } else {
          jclass cls = jniEnv->GetObjectClass(globalDelegateRef);
          jmethodID mid = jniEnv->GetMethodID(
              cls, "emitOnMessageFromJS", "(Ljava/lang/String;)V");
          jstring jMsg = jniEnv->NewStringUTF(messageJson.c_str());
          jniEnv->CallVoidMethod(globalDelegateRef, mid, jMsg);
          jniEnv->DeleteLocalRef(jMsg);
          jniEnv->DeleteLocalRef(cls);
        }

        return jsi::Value::undefined();
      });

  auto setOnMessageFn = jsi::Function::createFromHostFunction(
      runtime,
      jsi::PropNameID::forAscii(runtime, "setOnMessage"),
      1,
      [stateWeak = std::weak_ptr<SandboxJSIState>(state)](
          jsi::Runtime& rt,
          const jsi::Value&,
          const jsi::Value* args,
          size_t count) -> jsi::Value {
        if (count != 1) {
          throw jsi::JSError(rt, "setOnMessage: expected exactly one argument");
        }
        if (!args[0].isObject() || !args[0].asObject(rt).isFunction(rt)) {
          throw jsi::JSError(rt, "setOnMessage: argument must be a function");
        }

        auto statePtr = stateWeak.lock();
        if (!statePtr)
          return jsi::Value::undefined();

        std::vector<std::string> buffered;
        {
          std::lock_guard<std::mutex> lock(statePtr->mutex);
          statePtr->onMessageCallback.reset();
          statePtr->onMessageCallback = std::make_shared<jsi::Function>(
              args[0].asObject(rt).asFunction(rt));
          buffered.swap(statePtr->pendingMessages);
        }

        for (const auto& msg : buffered) {
          try {
            jsi::Value parsed =
                rt.global()
                    .getPropertyAsObject(rt, "JSON")
                    .getPropertyAsFunction(rt, "parse")
                    .call(rt, jsi::String::createFromUtf8(rt, msg));
            statePtr->onMessageCallback->call(rt, std::move(parsed));
          } catch (const std::exception& e) {
            LOGE("Error flushing buffered message: %s", e.what());
          }
        }
        if (!buffered.empty()) {
          try {
            rt.drainMicrotasks();
          } catch (...) {
          }
        }

        return jsi::Value::undefined();
      });

  jsi::Function defineProperty =
      runtime.global()
          .getPropertyAsObject(runtime, "Object")
          .getPropertyAsFunction(runtime, "defineProperty");

  auto makePropDesc = [&](jsi::Function&& fn) {
    jsi::Object desc(runtime);
    desc.setProperty(runtime, "value", std::move(fn));
    desc.setProperty(runtime, "writable", false);
    desc.setProperty(runtime, "enumerable", false);
    desc.setProperty(runtime, "configurable", false);
    return desc;
  };

  defineProperty.call(
      runtime,
      runtime.global(),
      jsi::String::createFromAscii(runtime, "postMessage"),
      makePropDesc(std::move(postMessageFn)));

  defineProperty.call(
      runtime,
      runtime.global(),
      jsi::String::createFromAscii(runtime, "setOnMessage"),
      makePropDesc(std::move(setOnMessageFn)));

  try {
    setupErrorHandler(runtime, globalDelegateRef);
  } catch (const std::exception& e) {
    LOGW("Failed to setup error handler: %s", e.what());
  }

  return stateHandle;
}

extern "C" {

JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void*) {
  gJavaVM = vm;
  return facebook::jni::initialize(
      vm, [] { rnsandbox::SandboxBindingsInstaller::registerNatives(); });
}

JNIEXPORT jlong JNICALL
Java_io_callstack_rnsandbox_SandboxJSIInstaller_nativeInstall(
    JNIEnv* env,
    jclass,
    jlong runtimePtr,
    jobject delegateRef) {
  if (runtimePtr == 0) {
    LOGE("nativeInstall called with null runtime pointer");
    return 0;
  }

  auto* runtime = reinterpret_cast<jsi::Runtime*>(runtimePtr);
  return installSandboxJSIBindings(*runtime, env, delegateRef);
}

JNIEXPORT void JNICALL
Java_io_callstack_rnsandbox_SandboxJSIInstaller_nativePostMessage(
    JNIEnv* env,
    jclass,
    jlong stateHandle,
    jstring message) {
  std::shared_ptr<SandboxJSIState> state;
  {
    std::lock_guard<std::mutex> lock(gRegistryMutex);
    auto it = gStates.find(stateHandle);
    if (it == gStates.end())
      return;
    state = it->second;
  }

  const char* msgChars = env->GetStringUTFChars(message, nullptr);
  std::string messageStr(msgChars);
  env->ReleaseStringUTFChars(message, msgChars);

  std::lock_guard<std::mutex> lock(state->mutex);
  if (!state->runtime)
    return;

  if (!state->onMessageCallback) {
    state->pendingMessages.push_back(std::move(messageStr));
    return;
  }

  try {
    jsi::Runtime& rt = *state->runtime;
    jsi::Value parsed =
        rt.global()
            .getPropertyAsObject(rt, "JSON")
            .getPropertyAsFunction(rt, "parse")
            .call(rt, jsi::String::createFromUtf8(rt, messageStr));
    state->onMessageCallback->call(rt, std::move(parsed));

    // runOnJSQueueThread does not drain the microtask queue, so React/Fabric
    // never sees the state update. Drain explicitly to mirror what the
    // RuntimeExecutor (and iOS's callFunctionOnBufferedRuntimeExecutor) does.
    rt.drainMicrotasks();
  } catch (const jsi::JSError& e) {
    LOGE("JSError in postMessage: %s", e.getMessage().c_str());
  } catch (const std::exception& e) {
    LOGE("Exception in postMessage: %s", e.what());
  }
}

JNIEXPORT void JNICALL
Java_io_callstack_rnsandbox_SandboxJSIInstaller_nativeDestroy(
    JNIEnv*,
    jclass,
    jlong stateHandle) {
  std::lock_guard<std::mutex> lock(gRegistryMutex);
  auto it = gStates.find(stateHandle);
  if (it != gStates.end()) {
    {
      std::lock_guard<std::mutex> stateLock(it->second->mutex);
      it->second->onMessageCallback.reset();
      it->second->pendingMessages.clear();
      it->second->runtime = nullptr;
    }
    gStates.erase(it);
  }
}

} // extern "C"
