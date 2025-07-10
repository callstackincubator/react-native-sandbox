//
//  SandboxReactNativeDelegate.h
//  MultiInstancePOC
//
//  Created by Aliaksandr Babrykovich on 25/06/2025.
//

#import "SandboxReactNativeDelegate.h"

#include <memory>
#include <jsi/decorator.h>
#include <react/utils/jsi-utils.h>

#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>
#import <ReactAppDependencyProvider/RCTAppDependencyProvider.h>
#import <ReactCommon/RCTTurboModule.h>

#import <objc/runtime.h>

namespace jsi = facebook::jsi;
namespace TurboModuleConvertUtils = facebook::react::TurboModuleConvertUtils;

static void stubJsiFunction(jsi::Runtime& runtime, jsi::Object& object, const char* name) {
  object.setProperty(runtime, name,
    jsi::Function::createFromHostFunction(runtime,
      jsi::PropNameID::forUtf8(runtime, name), 1,
      [](auto&, const auto&, const auto*, size_t) {
        return jsi::Value::undefined();
      }
    )
  );
}

static jsi::Value safeGetProperty(jsi::Runtime& rt, const jsi::Object& obj, const char* key) {
  return obj.hasProperty(rt, key)
    ? obj.getProperty(rt, key)
    : jsi::Value::undefined();
}

@interface SandboxReactNativeDelegate () {
  RCTInstance *_rctInstance;
  std::shared_ptr<jsi::Function> _onMessageSandbox;
  std::set<std::string> _allowedModules;
}

@property (nonatomic, strong) NSString *jsBundleName;

@end

@implementation SandboxReactNativeDelegate

- (void)setAllowedTurmoboModules:(NSArray<NSString *> *)allowedTurmoboModules {
  _allowedModules.clear();
  for (NSString *s in allowedTurmoboModules) {
    _allowedModules.insert([s UTF8String]);
  }
}

- (instancetype)initWithJSBundleName:(NSString *)jsBundleName {
  if (self = [super init]) {
    _jsBundleName = jsBundleName;
    _onMessageHost = nil;
    _onErrorHost = nil;
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

- (void)postMessage:(NSDictionary *)message {
  [_rctInstance callFunctionOnBufferedRuntimeExecutor:[=](jsi::Runtime& runtime) {
    jsi::Value arg = TurboModuleConvertUtils::convertObjCObjectToJSIValue(runtime, message);
    _onMessageSandbox->call(runtime, { std::move(arg) });
  }];
}

- (void)hostDidStart:(RCTHost *)host {
  Ivar ivar = class_getInstanceVariable([host class], "_instance");
  _rctInstance = object_getIvar(host, ivar);

  [_rctInstance callFunctionOnBufferedRuntimeExecutor:[=](jsi::Runtime &runtime) {
    // TODO: migrate to defineReadOnlyGlobal
    facebook::react::defineReadOnlyGlobal(runtime,
      "postMessage",
      jsi::Function::createFromHostFunction(
        runtime,
        jsi::PropNameID::forAscii(runtime, "postMessage"),
        1,
        [=](jsi::Runtime& rt, const jsi::Value&, const jsi::Value* args, size_t count) {
          if (count != 1) {
            throw jsi::JSError(rt, "Expected exactly one argument");
          }

          const jsi::Value& arg = args[0];
          if (!arg.isObject()) {
            throw jsi::JSError(rt, "Expected a object as the first argument");
          }

          NSDictionary *message = TurboModuleConvertUtils::convertJSIValueToObjCObject(rt, args[0], nullptr);
          _onMessageHost(message);
          return jsi::Value::undefined();
        })
    );
    facebook::react::defineReadOnlyGlobal(
      runtime,
      "useOnMessage",
      jsi::Function::createFromHostFunction(
        runtime,
        jsi::PropNameID::forAscii(runtime, "useOnMessage"),
        1,
        [=](jsi::Runtime& rt, const jsi::Value&, const jsi::Value* args, size_t count) {
          if (count != 1) {
            throw jsi::JSError(rt, "Expected exactly one argument");
          }

          const jsi::Value& arg = args[0];
          if (!arg.isObject() || !arg.asObject(rt).isFunction(rt)) {
            throw jsi::JSError(rt, "Expected a function as the first argument");
          }

          jsi::Function fn = arg.asObject(rt).asFunction(rt);
          _onMessageSandbox = std::make_shared<jsi::Function>(std::move(fn));

          return jsi::Value::undefined();
        })
    );

    // Get ErrorUtils
    jsi::Object global = runtime.global();
    jsi::Value errorUtilsVal = global.getProperty(runtime, "ErrorUtils");
    if (!errorUtilsVal.isObject()) {
      throw std::runtime_error("ErrorUtils is not available on global object");
    }

    jsi::Object errorUtils = errorUtilsVal.asObject(runtime);

    std::shared_ptr<jsi::Value> originalHandler =  std::make_shared<jsi::Value>(errorUtils.getProperty(runtime, "getGlobalHandler")
                                      .asObject(runtime)
                                      .asFunction(runtime)
                                      .call(runtime));

    auto handlerFunc = jsi::Function::createFromHostFunction(
      runtime,
      jsi::PropNameID::forAscii(runtime, "customGlobalErrorHandler"),
      2,
      [=, originalHandler = std::move(originalHandler)](jsi::Runtime &rt,
                                                     const jsi::Value &thisVal,
                                                     const jsi::Value *args,
                                                     size_t count) -> jsi::Value {
        if (count < 2) {
          return jsi::Value::undefined();
        }

        if (_onErrorHost) {
          const jsi::Object &error = args[0].asObject(rt);
          bool isFatal = args[1].getBool();
          _onErrorHost(@{
            @"name": TurboModuleConvertUtils::convertJSIValueToObjCObject(rt, safeGetProperty(rt, error, "name"), nullptr),
            @"message": TurboModuleConvertUtils::convertJSIValueToObjCObject(rt, safeGetProperty(rt, error, "message"), nullptr),
            @"stack": TurboModuleConvertUtils::convertJSIValueToObjCObject(rt, safeGetProperty(rt, error, "stack"), nullptr),
            @"isFatal": @(isFatal)
          });
        } else { // Call the original handler
          if (originalHandler->isObject() && originalHandler->asObject(rt).isFunction(rt)) {
            jsi::Function original = originalHandler->asObject(rt).asFunction(rt);
            original.call(rt, args, count);
          }
        }

        return jsi::Value::undefined();
      }
    );

    // Set the new global error handler
    jsi::Function setHandler = errorUtils.getProperty(runtime, "setGlobalHandler").asObject(runtime).asFunction(runtime);
    setHandler.call(runtime, { std::move(handlerFunc) });

    // Disable further setGlobalHandler from sandbox
    stubJsiFunction(runtime, errorUtils, "setGlobalHandler");
  }];
}

#pragma mark - RCTTurboModuleManagerDelegate

- (id<RCTModuleProvider>)getModuleProvider:(const char *)name {
  NSLog(@"SandboxReactNativeDelegate.getModuleProvider %s", name);
  return _allowedModules.contains(name) ? [super getModuleProvider:name] : nullptr;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const std::string &)name
                                                      jsInvoker:
(std::shared_ptr<facebook::react::CallInvoker>)jsInvoker {
  NSLog(@"SandboxReactNativeDelegate.getTurboModule:jsInvoker %s", name.c_str());
  return _allowedModules.contains(name) ? [super getTurboModule:name jsInvoker:jsInvoker] : nullptr;
}

@end
