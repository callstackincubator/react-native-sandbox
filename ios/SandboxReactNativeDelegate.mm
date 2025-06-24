//
//  SandboxReactNativeDelegate.h
//  MultiInstancePOC
//
//  Created by Aliaksandr Babrykovich on 25/06/2025.
//

#import "SandboxReactNativeDelegate.h"

#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>
#import <ReactAppDependencyProvider/RCTAppDependencyProvider.h>

#include <react/runtime/JSRuntimeFactory.h>              // facebook::jsi::JSRuntimeFactory
#include <jsi/decorator.h>

@interface SandboxReactNativeDelegate ()
@property (nonatomic, strong) NSString *jsBundleName;
@end

@implementation SandboxReactNativeDelegate

- (instancetype)initWithJSBundleName:(NSString *)jsBundleName {
  if (self = [super init]) {
    _jsBundleName = jsBundleName;
    self.dependencyProvider = [[RCTAppDependencyProvider alloc] init];
  }
  return self;
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge {
  return [self bundleURL];
}

- (NSURL *)bundleURL {
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:self.jsBundleName];
#else
  return [[NSBundle mainBundle] URLForResource:self.jsBundleName withExtension:@"jsbundle"];
#endif
}

- (JSRuntimeFactoryRef) createJSRuntimeFactory {
  using namespace facebook;

  react::JSRuntimeFactory *base = (react::JSRuntimeFactory *)[super createJSRuntimeFactory];

  struct ProxyFactory : react::JSRuntimeFactory {
    ProxyFactory(react::JSRuntimeFactory *baseFactory)
        : baseFactory_(baseFactory) {}

    std::unique_ptr<react::JSRuntime> createJSRuntime(
        std::shared_ptr<react::MessageQueueThread> thread) noexcept override {
      auto runtime = baseFactory_->createJSRuntime(std::move(thread));
      // TOOD: declare globals
      // postMessage(payload) and useOnMessage(onMessage)
      return runtime;
    }

   private:
    react::JSRuntimeFactory *baseFactory_;  // non-owning
  };

  auto *hooked = new ProxyFactory(base);
  return (JSRuntimeFactoryRef)hooked;
}

// TODO: implement RCTTurboModuleManagerDelegate methods for security reasons i.e. not expose allow auto expose turbo-modules from host to sandbox

@end
