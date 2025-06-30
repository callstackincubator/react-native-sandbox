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
#import <ReactCommon/RCTHost.h>

#import <objc/runtime.h>

#include <jsi/decorator.h>

#include "JSObjectMethodProxy.hpp"

namespace jsi = facebook::jsi;

@interface SandboxReactNativeDelegate ()<RCTHostRuntimeDelegate> {
  std::unique_ptr<JSObjectMethodProxy> _reportErrorProxy;
}

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

// TODO: move to "- (void)hostDidStart:(RCTHost *)host;" which is part of RCTHostDelegate
- (void)host:(RCTHost *)host didInitializeRuntime:(facebook::jsi::Runtime &)runtime {
  Ivar ivar = class_getInstanceVariable([host class], "_instance");
  RCTInstance *instance = object_getIvar(host, ivar);
  facebook::react::ReactInstance *reactInstance = ((__bridge std::unique_ptr<facebook::react::ReactInstance> *)instance)->get();
  // reactInstance->initializeRuntime(facebook::react::JSRuntimeFlags(), BindingsInstallFunc bindingsInstallFunc)
  facebook::react::ReactInstance::JSRuntimeFlags options;
  [instance callFunctionOnBufferedRuntimeExecutor:[=](jsi::Runtime &runtime) {
    runtime.global().setProperty(
      runtime,
      "postMessage",
      jsi::Function::createFromHostFunction(
        runtime,
        jsi::PropNameID::forAscii(runtime, "postMessage"),
        1,
        [](jsi::Runtime&, const jsi::Value&, const jsi::Value* args, size_t count) {
          // clone
          // call onMessage
          return jsi::Value::undefined();
        })
    );
    runtime.global().setProperty(
      runtime,
      "useOnMessage",
      jsi::Function::createFromHostFunction(
        runtime,
        jsi::PropNameID::forAscii(runtime, "useOnMessage"),
        1,
        [](jsi::Runtime&, const jsi::Value&, const jsi::Value* args, size_t count) {
          // clone
          // store onMessage function from jsi::Value* args
          return jsi::Value::undefined();
        })
    );

    auto errorUtils = runtime.global().getPropertyAsObject(runtime, "ErrorUtils");

  //  if (errorUtils.isUndefined() || !errorUtils.isObject()) {
  //    return;
  //  }
    _reportErrorProxy = std::make_unique<JSObjectMethodProxy>(
      runtime,
      errorUtils,
      "reportError",
      1,
      [](const jsi::Runtime &rt, const jsi::Value *args, size_t count) {
        // Decide if original should be called
        return true;
      }
    );
  }];
}

- (void)host:(RCTHost *)host didReceiveJSErrorStack:(NSArray<NSDictionary<NSString *,id> *> *)stack message:(NSString *)message originalMessage:(NSString *)originalMessage name:(NSString *)name componentStack:(NSString *)componentStack exceptionId:(NSUInteger)exceptionId isFatal:(BOOL)isFatal extraData:(NSDictionary<NSString *,id> *)extraData {
  NSLog(@"didReceiveJSErrorStack");
}

- (void)hostDidStart:(RCTHost *)host {
  NSLog(@"hostDidStart");
}



// TODO: implement RCTTurboModuleManagerDelegate methods for security reasons i.e. not expose allow auto expose turbo-modules from host to sandbox +1

@end
