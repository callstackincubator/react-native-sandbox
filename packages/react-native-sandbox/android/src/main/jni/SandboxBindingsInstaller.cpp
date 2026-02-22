#include "SandboxBindingsInstaller.h"

#include <android/log.h>

#define LOG_TAG "SandboxJSI"
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace jsi = facebook::jsi;
namespace jni = facebook::jni;

extern jlong installSandboxJSIBindings(
    jsi::Runtime& runtime,
    JNIEnv* env,
    jobject delegateRef);

namespace rnsandbox {

SandboxBindingsInstaller::SandboxBindingsInstaller(
    jni::alias_ref<jobject> delegateRef)
    : delegateRef_(jni::make_global(delegateRef)) {}

jni::local_ref<SandboxBindingsInstaller::jhybriddata>
SandboxBindingsInstaller::initHybrid(
    jni::alias_ref<jclass>,
    jni::alias_ref<jobject> delegateRef) {
  return makeCxxInstance(delegateRef);
}

void SandboxBindingsInstaller::registerNatives() {
  registerHybrid({
      makeNativeMethod("initHybrid", SandboxBindingsInstaller::initHybrid),
  });
}

facebook::react::ReactInstance::BindingsInstallFunc
SandboxBindingsInstaller::getBindingsInstallFunc() {
  auto delegateRef = delegateRef_;
  return [delegateRef](jsi::Runtime& runtime) {
    JNIEnv* env = jni::Environment::current();
    if (!env) {
      LOGE("BindingsInstaller: no JNI environment");
      return;
    }

    jobject rawDelegate = delegateRef.get();

    jclass cls = env->GetObjectClass(rawDelegate);
    jmethodID onInstalled =
        env->GetMethodID(cls, "onJSIBindingsInstalled", "(J)V");
    env->DeleteLocalRef(cls);

    jlong stateHandle = ::installSandboxJSIBindings(runtime, env, rawDelegate);

    if (onInstalled) {
      env->CallVoidMethod(rawDelegate, onInstalled, stateHandle);
    }
  };
}

} // namespace rnsandbox
