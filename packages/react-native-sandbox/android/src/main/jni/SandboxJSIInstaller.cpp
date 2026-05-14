#include "ISandboxDelegate.h"
#include "SandboxBindingsInstaller.h"
#include "SandboxLogBox.h"
#include "SandboxRegistry.h"

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
  // Per-surface message callbacks keyed by delegate ID.
  // When a sandbox uses useSurfaceMessaging, its setOnMessage registers here
  // so each surface gets its own listener even in a shared VM.
  std::unordered_map<std::string, std::shared_ptr<jsi::Function>>
      surfaceMessageCallbacks;
  std::vector<std::string> pendingMessages;
  std::mutex mutex;
  jobject delegateRef = nullptr;
  std::string origin;
  std::shared_ptr<rnsandbox::ISandboxDelegate> registryDelegate;
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

/**
 * ISandboxDelegate that dispatches postMessage through the Kotlin delegate
 * via JNI. The Kotlin postMessage uses runOnJSQueueThread to safely access
 * the JSI runtime on the correct thread.
 *
 * Holds its own JNI global reference which must be released via invalidate().
 */
class JNISandboxDelegate : public rnsandbox::ISandboxDelegate {
 public:
  explicit JNISandboxDelegate(JNIEnv* env, jobject delegateRef)
      : globalDelegateRef_(env->NewGlobalRef(delegateRef)) {}

  ~JNISandboxDelegate() override {
    invalidate();
  }

  void invalidate() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (globalDelegateRef_) {
      JNIEnv* env = getJNIEnv();
      if (env) {
        env->DeleteGlobalRef(globalDelegateRef_);
      }
      globalDelegateRef_ = nullptr;
    }
  }

  void postMessage(const std::string& message) override {
    std::lock_guard<std::mutex> lock(mutex_);
    JNIEnv* env = getJNIEnv();
    if (!env || !globalDelegateRef_)
      return;
    jclass cls = env->GetObjectClass(globalDelegateRef_);
    jmethodID mid =
        env->GetMethodID(cls, "postMessage", "(Ljava/lang/String;)V");
    jstring jMsg = env->NewStringUTF(message.c_str());
    env->CallVoidMethod(globalDelegateRef_, mid, jMsg);
    env->DeleteLocalRef(jMsg);
    env->DeleteLocalRef(cls);
  }

  bool routeMessage(const std::string& message, const std::string& targetId)
      override {
    auto& registry = rnsandbox::SandboxRegistry::getInstance();

    // Enforce allowedOrigins access control
    if (!origin_.empty() && !registry.isPermittedFrom(origin_, targetId)) {
      postError(
          "AccessDeniedError",
          "Access denied: Sandbox '" + origin_ +
              "' is not permitted to send messages to '" + targetId + "'",
          "",
          false);
      return false;
    }

    auto targets = registry.findAll(targetId);
    if (targets.empty())
      return false;
    for (auto& target : targets) {
      target->postMessage(message);
    }
    return true;
  }

  void setOrigin(const std::string& origin) override {
    origin_ = origin;
  }
  void setAllowedOrigins(const std::set<std::string>&) override {}
  void setAllowedTurboModules(const std::set<std::string>&) override {}

  /**
   * Calls the Kotlin delegate's emitOnMessageFromJS to route a message
   * from the sandbox JS to the host native view. This is the JS→Host
   * direction, as opposed to postMessage() which is Host→JS.
   */
  void emitOnMessageFromJS(const std::string& message) {
    std::lock_guard<std::mutex> lock(mutex_);
    JNIEnv* env = getJNIEnv();
    if (!env || !globalDelegateRef_)
      return;
    jclass cls = env->GetObjectClass(globalDelegateRef_);
    jmethodID mid =
        env->GetMethodID(cls, "emitOnMessageFromJS", "(Ljava/lang/String;)V");
    jstring jMsg = env->NewStringUTF(message.c_str());
    env->CallVoidMethod(globalDelegateRef_, mid, jMsg);
    env->DeleteLocalRef(jMsg);
    env->DeleteLocalRef(cls);
  }

  void postError(
      const std::string& name,
      const std::string& message,
      const std::string& stack,
      bool isFatal) override {
    std::lock_guard<std::mutex> lock(mutex_);
    JNIEnv* env = getJNIEnv();
    if (!env || !globalDelegateRef_)
      return;
    jclass cls = env->GetObjectClass(globalDelegateRef_);
    jmethodID mid = env->GetMethodID(
        cls,
        "emitOnErrorFromJS",
        "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Z)V");
    jstring jName = env->NewStringUTF(name.c_str());
    jstring jMsg = env->NewStringUTF(message.c_str());
    jstring jStack = env->NewStringUTF(stack.c_str());
    env->CallVoidMethod(
        globalDelegateRef_, mid, jName, jMsg, jStack, (jboolean)isFatal);
    env->DeleteLocalRef(jName);
    env->DeleteLocalRef(jMsg);
    env->DeleteLocalRef(jStack);
    env->DeleteLocalRef(cls);
  }

 private:
  jobject globalDelegateRef_;
  std::string origin_;
  std::mutex mutex_;
};

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
    std::weak_ptr<SandboxJSIState> stateWeak) {
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
      [stateWeak, originalHandler = std::move(originalHandler)](
          jsi::Runtime& rt,
          const jsi::Value&,
          const jsi::Value* args,
          size_t count) -> jsi::Value {
        if (count < 2)
          return jsi::Value::undefined();

        auto state = stateWeak.lock();
        if (!state || !state->delegateRef)
          return jsi::Value::undefined();

        JNIEnv* jniEnv = getJNIEnv();
        if (!jniEnv)
          return jsi::Value::undefined();

        const jsi::Object& error = args[0].asObject(rt);
        bool isFatal = args[1].getBool();
        std::string name = safeGetStringProperty(rt, error, "name");
        std::string message = safeGetStringProperty(rt, error, "message");
        std::string stack = safeGetStringProperty(rt, error, "stack");

        bool handled = false;

        // When an origin is set, broadcast the error to ALL delegates
        // registered for this origin so every view sharing the VM can
        // independently receive onError events.
        if (!state->origin.empty()) {
          auto& registry = rnsandbox::SandboxRegistry::getInstance();
          auto delegates = registry.findAll(state->origin);
          for (auto& delegate : delegates) {
            // Each JNISandboxDelegate routes through the Kotlin delegate
            // which checks hasOnErrorHandler before emitting.
            delegate->postError(name, message, stack, isFatal);
            handled = true;
          }
        }

        if (!handled) {
          jclass cls = jniEnv->GetObjectClass(state->delegateRef);
          jfieldID hasHandlerField =
              jniEnv->GetFieldID(cls, "hasOnErrorHandler", "Z");
          jboolean hasHandler =
              jniEnv->GetBooleanField(state->delegateRef, hasHandlerField);

          if (hasHandler) {
            jmethodID emitMethod = jniEnv->GetMethodID(
                cls,
                "emitOnErrorFromJS",
                "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Z)V");
            jstring jName = jniEnv->NewStringUTF(name.c_str());
            jstring jMsg = jniEnv->NewStringUTF(message.c_str());
            jstring jStack = jniEnv->NewStringUTF(stack.c_str());
            jniEnv->CallVoidMethod(
                state->delegateRef,
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
        }

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
  state->delegateRef = globalDelegateRef;

  auto postMessageFn = jsi::Function::createFromHostFunction(
      runtime,
      jsi::PropNameID::forAscii(runtime, "postMessage"),
      2,
      [stateWeak = std::weak_ptr<SandboxJSIState>(state)](
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

        auto statePtr = stateWeak.lock();
        if (!statePtr || !statePtr->delegateRef)
          return jsi::Value::undefined();

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

          auto& registry = rnsandbox::SandboxRegistry::getInstance();

          // Check if target exists before checking permissions
          auto targets = registry.findAll(targetOrigin);
          if (targets.empty()) {
            // Target not found — broadcast routing error to all delegates
            // for the sender's origin so every surface sees it.
            if (!statePtr->origin.empty()) {
              auto senderDelegates = registry.findAll(statePtr->origin);
              std::string errMsg =
                  "Target sandbox '" + targetOrigin + "' not found";
              for (auto& d : senderDelegates) {
                d->postError("SandboxRoutingError", errMsg, "", false);
              }
            } else if (statePtr->registryDelegate) {
              std::string errMsg =
                  "Target sandbox '" + targetOrigin + "' not found";
              statePtr->registryDelegate->postError(
                  "SandboxRoutingError", errMsg, "", false);
            } else {
              LOGW("postMessage: target '%s' not found", targetOrigin.c_str());
            }
            return jsi::Value(false);
          }

          // Enforce allowedOrigins access control
          if (!registry.isPermittedFrom(statePtr->origin, targetOrigin)) {
            if (!statePtr->origin.empty()) {
              auto senderDelegates = registry.findAll(statePtr->origin);
              std::string errMsg = "Access denied: Sandbox '" +
                  statePtr->origin +
                  "' is not permitted to send messages to '" + targetOrigin +
                  "'";
              for (auto& d : senderDelegates) {
                d->postError("AccessDeniedError", errMsg, "", false);
              }
            } else if (statePtr->registryDelegate) {
              std::string errMsg = "Access denied: Sandbox '" +
                  statePtr->origin +
                  "' is not permitted to send messages to '" + targetOrigin +
                  "'";
              statePtr->registryDelegate->postError(
                  "AccessDeniedError", errMsg, "", false);
            }
            return jsi::Value(false);
          }

          // All delegates for a given origin share the same JS runtime
          // and setOnMessage callbacks, so deliver to JS only once.
          targets.front()->postMessage(messageJson);
        } else if (!statePtr->origin.empty()) {
          // Per-surface routing: if the message contains __sandboxDelegateId,
          // route only to that specific delegate instead of broadcasting.
          std::string delegateId;
          if (args[0].isObject()) {
            jsi::Object msgObj = args[0].getObject(rt);
            jsi::Value idVal = msgObj.getProperty(rt, "__sandboxDelegateId");
            if (idVal.isString()) {
              delegateId = idVal.getString(rt).utf8(rt);
              // Create a shallow copy without __sandboxDelegateId to avoid
              // mutating the caller's object (which may be frozen/sealed).
              jsi::Object copy(rt);
              jsi::Array names = msgObj.getPropertyNames(rt);
              size_t len = names.size(rt);
              for (size_t i = 0; i < len; ++i) {
                jsi::String name = names.getValueAtIndex(rt, i).getString(rt);
                if (name.utf8(rt) != "__sandboxDelegateId") {
                  copy.setProperty(rt, name, msgObj.getProperty(rt, name));
                }
              }
              messageJson = stringify.call(rt, copy).getString(rt).utf8(rt);
            }
          }

          if (!delegateId.empty()) {
            // Route to the specific delegate identified by delegateId
            jclass delegateCls = jniEnv->FindClass(
                "io/callstack/rnsandbox/SandboxReactNativeDelegate");
            jmethodID findMethod = jniEnv->GetStaticMethodID(
                delegateCls,
                "findByDelegateId",
                "(Ljava/lang/String;)"
                "Lio/callstack/rnsandbox/SandboxReactNativeDelegate;");
            jstring jDelegateId = jniEnv->NewStringUTF(delegateId.c_str());
            jobject targetDelegate = jniEnv->CallStaticObjectMethod(
                delegateCls, findMethod, jDelegateId);
            if (targetDelegate) {
              jclass cls = jniEnv->GetObjectClass(targetDelegate);
              jmethodID mid = jniEnv->GetMethodID(
                  cls, "emitOnMessageFromJS", "(Ljava/lang/String;)V");
              jstring jMsg = jniEnv->NewStringUTF(messageJson.c_str());
              jniEnv->CallVoidMethod(targetDelegate, mid, jMsg);
              jniEnv->DeleteLocalRef(jMsg);
              jniEnv->DeleteLocalRef(cls);
              jniEnv->DeleteLocalRef(targetDelegate);
            }
            jniEnv->DeleteLocalRef(jDelegateId);
            jniEnv->DeleteLocalRef(delegateCls);
          } else {
            // No delegate ID — broadcast to all delegates (backward compat)
            auto& registry = rnsandbox::SandboxRegistry::getInstance();
            auto delegates = registry.findAll(statePtr->origin);
            for (auto& delegate : delegates) {
              auto* jniDelegate =
                  dynamic_cast<JNISandboxDelegate*>(delegate.get());
              if (jniDelegate) {
                jniDelegate->emitOnMessageFromJS(messageJson);
              }
            }
          }
        } else {
          jclass cls = jniEnv->GetObjectClass(statePtr->delegateRef);
          jmethodID mid = jniEnv->GetMethodID(
              cls, "emitOnMessageFromJS", "(Ljava/lang/String;)V");
          jstring jMsg = jniEnv->NewStringUTF(messageJson.c_str());
          jniEnv->CallVoidMethod(statePtr->delegateRef, mid, jMsg);
          jniEnv->DeleteLocalRef(jMsg);
          jniEnv->DeleteLocalRef(cls);
        }

        return jsi::Value::undefined();
      });

  auto setOnMessageFn = jsi::Function::createFromHostFunction(
      runtime,
      jsi::PropNameID::forAscii(runtime, "setOnMessage"),
      2,
      [stateWeak = std::weak_ptr<SandboxJSIState>(state)](
          jsi::Runtime& rt,
          const jsi::Value&,
          const jsi::Value* args,
          size_t count) -> jsi::Value {
        if (count < 1 || count > 2) {
          throw jsi::JSError(
              rt, "setOnMessage(callback, delegateId?): expected 1 or 2 args");
        }
        if (!args[0].isObject() || !args[0].asObject(rt).isFunction(rt)) {
          throw jsi::JSError(rt, "setOnMessage: argument must be a function");
        }

        auto statePtr = stateWeak.lock();
        if (!statePtr)
          return jsi::Value::undefined();

        // Check for optional delegate ID (2nd arg) for per-surface registration
        std::string delegateId;
        if (count == 2 && args[1].isString()) {
          delegateId = args[1].getString(rt).utf8(rt);
        }

        std::vector<std::string> buffered;
        auto fn = std::make_shared<jsi::Function>(
            args[0].asObject(rt).asFunction(rt));
        {
          std::lock_guard<std::mutex> lock(statePtr->mutex);
          if (!delegateId.empty()) {
            // Per-surface: register under the delegate ID
            statePtr->surfaceMessageCallbacks[delegateId] = fn;
          } else {
            // Legacy: single shared callback
            statePtr->onMessageCallback.reset();
            statePtr->onMessageCallback = fn;
          }
          buffered.swap(statePtr->pendingMessages);
        }

        for (const auto& msg : buffered) {
          try {
            jsi::Value parsed =
                rt.global()
                    .getPropertyAsObject(rt, "JSON")
                    .getPropertyAsFunction(rt, "parse")
                    .call(rt, jsi::String::createFromUtf8(rt, msg));
            fn->call(rt, std::move(parsed));
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
    setupErrorHandler(runtime, std::weak_ptr<SandboxJSIState>(state));
  } catch (const std::exception& e) {
    LOGW("Failed to setup error handler: %s", e.what());
  }

  rnsandbox::disableFuseboxLogBoxToast(runtime);

  // Register in C++ SandboxRegistry if origin is set
  {
    JNIEnv* jniEnv = getJNIEnv();
    if (jniEnv) {
      jclass cls = jniEnv->GetObjectClass(globalDelegateRef);
      jfieldID originField =
          jniEnv->GetFieldID(cls, "origin", "Ljava/lang/String;");
      auto jOrigin =
          (jstring)jniEnv->GetObjectField(globalDelegateRef, originField);

      // Read allowedOrigins from the delegate
      std::set<std::string> allowedOrigins;
      jfieldID allowedOriginsField =
          jniEnv->GetFieldID(cls, "allowedOrigins", "Ljava/util/Set;");
      jobject jAllowedOrigins =
          jniEnv->GetObjectField(globalDelegateRef, allowedOriginsField);
      if (jAllowedOrigins) {
        jclass setClass = jniEnv->FindClass("java/util/Set");
        jmethodID iteratorMethod =
            jniEnv->GetMethodID(setClass, "iterator", "()Ljava/util/Iterator;");
        jobject iterator =
            jniEnv->CallObjectMethod(jAllowedOrigins, iteratorMethod);
        jclass iterClass = jniEnv->FindClass("java/util/Iterator");
        jmethodID hasNextMethod =
            jniEnv->GetMethodID(iterClass, "hasNext", "()Z");
        jmethodID nextMethod =
            jniEnv->GetMethodID(iterClass, "next", "()Ljava/lang/Object;");
        while (jniEnv->CallBooleanMethod(iterator, hasNextMethod)) {
          auto jStr = (jstring)jniEnv->CallObjectMethod(iterator, nextMethod);
          if (jStr) {
            const char* chars = jniEnv->GetStringUTFChars(jStr, nullptr);
            allowedOrigins.insert(std::string(chars));
            jniEnv->ReleaseStringUTFChars(jStr, chars);
            jniEnv->DeleteLocalRef(jStr);
          }
        }
        jniEnv->DeleteLocalRef(iterator);
        jniEnv->DeleteLocalRef(iterClass);
        jniEnv->DeleteLocalRef(setClass);
        jniEnv->DeleteLocalRef(jAllowedOrigins);
      }

      jniEnv->DeleteLocalRef(cls);
      if (jOrigin) {
        const char* originChars = jniEnv->GetStringUTFChars(jOrigin, nullptr);
        std::string origin(originChars);
        jniEnv->ReleaseStringUTFChars(jOrigin, originChars);
        jniEnv->DeleteLocalRef(jOrigin);
        if (!origin.empty()) {
          state->origin = origin;
          auto delegate =
              std::make_shared<JNISandboxDelegate>(jniEnv, globalDelegateRef);
          delegate->setOrigin(origin);
          state->registryDelegate = delegate;
          rnsandbox::SandboxRegistry::getInstance().registerSandbox(
              origin, delegate, allowedOrigins);
        }
      }
    }
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

  // Copy callbacks out while holding the lock, then release before invoking
  // them. This prevents a deadlock if a JS callback synchronously calls
  // setOnMessage (or similar), which would attempt to re-acquire state->mutex
  // — a non-recursive std::mutex.
  std::shared_ptr<jsi::Function> onMsgCb;
  std::vector<std::shared_ptr<jsi::Function>> surfaceCbs;

  {
    std::lock_guard<std::mutex> lock(state->mutex);
    if (!state->runtime)
      return;

    if (!state->onMessageCallback && state->surfaceMessageCallbacks.empty()) {
      state->pendingMessages.push_back(std::move(messageStr));
      return;
    }

    onMsgCb = state->onMessageCallback;
    for (auto& [id, cb] : state->surfaceMessageCallbacks) {
      if (cb)
        surfaceCbs.push_back(cb);
    }
  }

  // Lock released — safe to invoke JS callbacks
  try {
    jsi::Runtime& rt = *state->runtime;
    jsi::Value parsed =
        rt.global()
            .getPropertyAsObject(rt, "JSON")
            .getPropertyAsFunction(rt, "parse")
            .call(rt, jsi::String::createFromUtf8(rt, messageStr));

    if (onMsgCb) {
      onMsgCb->call(rt, parsed);
    }

    for (auto& cb : surfaceCbs) {
      cb->call(rt, parsed);
    }

    rt.drainMicrotasks();
  } catch (const jsi::JSError& e) {
    LOGE("JSError in postMessage: %s", e.getMessage().c_str());
  } catch (const std::exception& e) {
    LOGE("Exception in postMessage: %s", e.what());
  }
}

// Holds a registered delegate so it can be unregistered later.
struct RegisteredDelegateHandle {
  std::string origin;
  std::shared_ptr<JNISandboxDelegate> delegate;
};

static std::mutex gDelegateHandleMutex;
static std::unordered_map<jlong, std::shared_ptr<RegisteredDelegateHandle>>
    gDelegateHandles;

JNIEXPORT void JNICALL
Java_io_callstack_rnsandbox_SandboxJSIInstaller_nativeInstallErrorHandler(
    JNIEnv*,
    jclass,
    jlong stateHandle) {
  std::shared_ptr<SandboxJSIState> state;
  {
    std::lock_guard<std::mutex> lock(gRegistryMutex);
    auto it = gStates.find(stateHandle);
    if (it == gStates.end())
      return;
    state = it->second;
  }

  std::lock_guard<std::mutex> lock(state->mutex);
  if (!state->runtime || !state->delegateRef)
    return;

  try {
    setupErrorHandler(*state->runtime, std::weak_ptr<SandboxJSIState>(state));
  } catch (const std::exception& e) {
    LOGW("Failed to setup error handler post-bundle: %s", e.what());
  }

  try {
    // Redundant with the pre-bundle call in installSandboxJSIBindings,
    // kept as a safety net for edge cases where the flag gets re-set.
    rnsandbox::disableFuseboxLogBoxToast(*state->runtime);
  } catch (const std::exception& e) {
    LOGW("Failed to disable LogBox: %s", e.what());
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
    std::string origin;
    std::shared_ptr<rnsandbox::ISandboxDelegate> delegate;
    jobject delegateRef = nullptr;
    {
      std::lock_guard<std::mutex> stateLock(it->second->mutex);
      origin = it->second->origin;
      delegate = it->second->registryDelegate;
      delegateRef = it->second->delegateRef;
      it->second->onMessageCallback.reset();
      it->second->surfaceMessageCallbacks.clear();
      it->second->pendingMessages.clear();
      it->second->runtime = nullptr;
      it->second->registryDelegate.reset();
      it->second->delegateRef = nullptr;
    }
    if (!origin.empty() && delegate) {
      rnsandbox::SandboxRegistry::getInstance().unregisterDelegate(
          origin, delegate);
    }
    if (delegateRef) {
      JNIEnv* env = getJNIEnv();
      if (env) {
        env->DeleteGlobalRef(delegateRef);
      }
    }
    gStates.erase(it);
  }
}

JNIEXPORT jlong JNICALL
Java_io_callstack_rnsandbox_SandboxJSIInstaller_nativeRegisterDelegate(
    JNIEnv* env,
    jclass,
    jstring origin,
    jobject delegateRef) {
  if (!origin || !delegateRef)
    return 0;

  const char* originChars = env->GetStringUTFChars(origin, nullptr);
  std::string originStr(originChars);
  env->ReleaseStringUTFChars(origin, originChars);

  if (originStr.empty())
    return 0;

  // Read allowedOrigins from the delegate
  std::set<std::string> allowedOrigins;
  jclass cls = env->GetObjectClass(delegateRef);
  jfieldID allowedOriginsField =
      env->GetFieldID(cls, "allowedOrigins", "Ljava/util/Set;");
  jobject jAllowedOrigins =
      env->GetObjectField(delegateRef, allowedOriginsField);
  if (jAllowedOrigins) {
    jclass setClass = env->FindClass("java/util/Set");
    jmethodID iteratorMethod =
        env->GetMethodID(setClass, "iterator", "()Ljava/util/Iterator;");
    jobject iterator = env->CallObjectMethod(jAllowedOrigins, iteratorMethod);
    jclass iterClass = env->FindClass("java/util/Iterator");
    jmethodID hasNextMethod = env->GetMethodID(iterClass, "hasNext", "()Z");
    jmethodID nextMethod =
        env->GetMethodID(iterClass, "next", "()Ljava/lang/Object;");
    while (env->CallBooleanMethod(iterator, hasNextMethod)) {
      auto jStr = (jstring)env->CallObjectMethod(iterator, nextMethod);
      if (jStr) {
        const char* chars = env->GetStringUTFChars(jStr, nullptr);
        allowedOrigins.insert(std::string(chars));
        env->ReleaseStringUTFChars(jStr, chars);
        env->DeleteLocalRef(jStr);
      }
    }
    env->DeleteLocalRef(iterator);
    env->DeleteLocalRef(iterClass);
    env->DeleteLocalRef(setClass);
    env->DeleteLocalRef(jAllowedOrigins);
  }
  env->DeleteLocalRef(cls);

  auto delegate = std::make_shared<JNISandboxDelegate>(env, delegateRef);
  delegate->setOrigin(originStr);
  rnsandbox::SandboxRegistry::getInstance().registerSandbox(
      originStr, delegate, allowedOrigins);

  auto handle = std::make_shared<RegisteredDelegateHandle>();
  handle->origin = originStr;
  handle->delegate = delegate;

  jlong handleId = reinterpret_cast<jlong>(handle.get());
  {
    std::lock_guard<std::mutex> lock(gDelegateHandleMutex);
    gDelegateHandles[handleId] = handle;
  }

  return handleId;
}

JNIEXPORT void JNICALL
Java_io_callstack_rnsandbox_SandboxJSIInstaller_nativeUnregisterDelegate(
    JNIEnv*,
    jclass,
    jlong handle) {
  std::lock_guard<std::mutex> lock(gDelegateHandleMutex);
  auto it = gDelegateHandles.find(handle);
  if (it != gDelegateHandles.end()) {
    auto& h = it->second;
    rnsandbox::SandboxRegistry::getInstance().unregisterDelegate(
        h->origin, h->delegate);
    h->delegate->invalidate();
    gDelegateHandles.erase(it);
  }
}

JNIEXPORT void JNICALL
Java_io_callstack_rnsandbox_SandboxJSIInstaller_nativeUnregisterStateDelegate(
    JNIEnv*,
    jclass,
    jlong stateHandle) {
  std::lock_guard<std::mutex> lock(gRegistryMutex);
  auto it = gStates.find(stateHandle);
  if (it != gStates.end()) {
    std::lock_guard<std::mutex> stateLock(it->second->mutex);
    auto& origin = it->second->origin;
    auto& delegate = it->second->registryDelegate;
    if (!origin.empty() && delegate) {
      rnsandbox::SandboxRegistry::getInstance().unregisterDelegate(
          origin, delegate);
      delegate.reset();
    }
  }
}

JNIEXPORT void JNICALL
Java_io_callstack_rnsandbox_SandboxJSIInstaller_nativeUpdateAllowedOrigins(
    JNIEnv* env,
    jclass,
    jstring origin,
    jobjectArray allowedOrigins) {
  if (!origin)
    return;

  const char* originChars = env->GetStringUTFChars(origin, nullptr);
  std::string originStr(originChars);
  env->ReleaseStringUTFChars(origin, originChars);

  if (originStr.empty())
    return;

  std::set<std::string> origins;
  if (allowedOrigins) {
    jsize len = env->GetArrayLength(allowedOrigins);
    for (jsize i = 0; i < len; i++) {
      auto jStr = (jstring)env->GetObjectArrayElement(allowedOrigins, i);
      if (jStr) {
        const char* chars = env->GetStringUTFChars(jStr, nullptr);
        origins.insert(std::string(chars));
        env->ReleaseStringUTFChars(jStr, chars);
        env->DeleteLocalRef(jStr);
      }
    }
  }

  auto& registry = rnsandbox::SandboxRegistry::getInstance();
  registry.updateAllowedOrigins(originStr, origins);
}

} // extern "C"
