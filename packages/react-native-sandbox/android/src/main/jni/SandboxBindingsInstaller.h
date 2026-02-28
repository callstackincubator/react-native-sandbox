#pragma once

#include <fbjni/fbjni.h>
#include <jsi/jsi.h>
#include <functional>

// ABI-compatible forward declarations for facebook::react types.
// We cannot include the real headers (react/runtime/BindingsInstaller.h)
// because they transitively pull in folly-config.h which isn't in
// Android's prefab distribution. The layout below matches the real
// classes exactly: same virtual methods, same inheritance order, same
// Java descriptors for fbjni.

namespace facebook::react {

class ReactInstance {
 public:
  using BindingsInstallFunc = std::function<void(facebook::jsi::Runtime&)>;
};

class BindingsInstaller {
 public:
  virtual ReactInstance::BindingsInstallFunc getBindingsInstallFunc() {
    return nullptr;
  }
};

class JBindingsInstaller
    : public facebook::jni::HybridClass<JBindingsInstaller>,
      public BindingsInstaller {
 public:
  static constexpr auto kJavaDescriptor =
      "Lcom/facebook/react/runtime/BindingsInstaller;";
  ~JBindingsInstaller() {}

 private:
  friend HybridBase;
};

} // namespace facebook::react

namespace rnsandbox {

class SandboxBindingsInstaller : public facebook::jni::HybridClass<
                                     SandboxBindingsInstaller,
                                     facebook::react::JBindingsInstaller> {
 public:
  static constexpr auto kJavaDescriptor =
      "Lio/callstack/rnsandbox/SandboxBindingsInstaller;";

  static facebook::jni::local_ref<jhybriddata> initHybrid(
      facebook::jni::alias_ref<jclass>,
      facebook::jni::alias_ref<jobject> delegateRef);

  static void registerNatives();

  facebook::react::ReactInstance::BindingsInstallFunc getBindingsInstallFunc()
      override;

 private:
  friend HybridBase;
  explicit SandboxBindingsInstaller(
      facebook::jni::alias_ref<jobject> delegateRef);

  facebook::jni::global_ref<jobject> delegateRef_;
};

} // namespace rnsandbox
