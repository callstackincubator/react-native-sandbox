//
//  SandboxReactNativeDelegate.h
//  react-native-sandbox
//
//  Created by Aliaksandr Babrykovich on 25/06/2025.
//

#import "SandboxReactNativeDelegate.h"
#import "StubTurboModuleCxx.h"

#include <jsi/JSIDynamic.h>
#include <jsi/decorator.h>
#include <react/utils/jsi-utils.h>
#include <memory>

#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTFollyConvert.h>
#import <ReactAppDependencyProvider/RCTAppDependencyProvider.h>
#import <ReactCommon/RCTTurboModule.h>

#import <objc/runtime.h>

namespace jsi = facebook::jsi;
namespace TurboModuleConvertUtils = facebook::react::TurboModuleConvertUtils;
using namespace facebook::react;

static void stubJsiFunction(jsi::Runtime &runtime, jsi::Object &object, const char *name)
{
  object.setProperty(
      runtime,
      name,
      jsi::Function::createFromHostFunction(
          runtime, jsi::PropNameID::forUtf8(runtime, name), 1, [](auto &, const auto &, const auto *, size_t) {
            return jsi::Value::undefined();
          }));
}

static std::string safeGetStringProperty(jsi::Runtime &rt, const jsi::Object &obj, const char *key)
{
  if (!obj.hasProperty(rt, key)) {
    return "";
  }
  jsi::Value value = obj.getProperty(rt, key);
  return value.isString() ? value.getString(rt).utf8(rt) : "";
}

@interface SandboxReactNativeDelegate () {
  RCTInstance *_rctInstance;
  std::shared_ptr<jsi::Function> _onMessageSandbox;
  std::set<std::string> _allowedModules;
}

@property (nonatomic, strong) NSString *jsBundleSource;

@end

@implementation SandboxReactNativeDelegate

- (void)setAllowedTurboModules:(NSArray<NSString *> *)allowedTurboModules
{
  _allowedModules.clear();
  for (NSString *s in allowedTurboModules) {
    _allowedModules.insert([s UTF8String]);
  }
}

- (instancetype)initWithJSBundleSource:(NSString *)jsBundleSource
{
  if (self = [super init]) {
    _jsBundleSource = jsBundleSource;
    _hasOnMessageHandler = NO;
    _hasOnErrorHandler = NO;
    self.dependencyProvider = [[RCTAppDependencyProvider alloc] init];
  }
  return self;
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
  return [self bundleURL];
}

- (NSURL *)bundleURL
{
  NSURL *url = [NSURL URLWithString:self.jsBundleSource];
  if (url && url.scheme) {
    return url;
  }

  if ([self.jsBundleSource hasSuffix:@".jsbundle"]) {
    return [[NSBundle mainBundle] URLForResource:self.jsBundleSource withExtension:nil];
  }

  NSString *bundleName = [self.jsBundleSource hasSuffix:@".bundle"]
      ? [self.jsBundleSource stringByDeletingPathExtension]
      : self.jsBundleSource;
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:bundleName];
}

- (void)postMessage:(NSString *)message
{
  if (!_onMessageSandbox) {
    return;
  }

  [_rctInstance callFunctionOnBufferedRuntimeExecutor:[=](jsi::Runtime &runtime) {
    try {
      std::string jsonString = [message UTF8String];

      jsi::Value parsedValue = runtime.global()
                                   .getPropertyAsObject(runtime, "JSON")
                                   .getPropertyAsFunction(runtime, "parse")
                                   .call(runtime, jsi::String::createFromUtf8(runtime, jsonString));

      _onMessageSandbox->call(runtime, {std::move(parsedValue)});
    } catch (const jsi::JSError &e) {
      if (self.eventEmitter && self.hasOnErrorHandler) {
        SandboxReactNativeViewEventEmitter::OnError errorEvent = {
            .isFatal = false, .name = "JSError", .message = e.getMessage(), .stack = e.getStack()};
        self.eventEmitter->onError(errorEvent);
      }
    } catch (const std::exception &e) {
      if (self.eventEmitter && self.hasOnErrorHandler) {
        SandboxReactNativeViewEventEmitter::OnError errorEvent = {
            .isFatal = false, .name = "JSONParseError", .message = e.what(), .stack = ""};
        self.eventEmitter->onError(errorEvent);
      }
    }
  }];
}

- (void)hostDidStart:(RCTHost *)host
{
  Ivar ivar = class_getInstanceVariable([host class], "_instance");
  _rctInstance = object_getIvar(host, ivar);

  [_rctInstance callFunctionOnBufferedRuntimeExecutor:[=](jsi::Runtime &runtime) {
    facebook::react::defineReadOnlyGlobal(
        runtime,
        "postMessage",
        jsi::Function::createFromHostFunction(
            runtime,
            jsi::PropNameID::forAscii(runtime, "postMessage"),
            1,
            [=](jsi::Runtime &rt, const jsi::Value &, const jsi::Value *args, size_t count) {
              if (count != 1) {
                throw jsi::JSError(rt, "Expected exactly one argument");
              }

              const jsi::Value &arg = args[0];
              if (!arg.isObject()) {
                throw jsi::JSError(rt, "Expected a object as the first argument");
              }

              if (self.eventEmitter && self.hasOnMessageHandler) {
                SandboxReactNativeViewEventEmitter::OnMessage messageEvent = {
                    .data = jsi::dynamicFromValue(rt, args[0])};
                self.eventEmitter->onMessage(messageEvent);
              }

              return jsi::Value::undefined();
            }));
    facebook::react::defineReadOnlyGlobal(
        runtime,
        "setOnMessage",
        jsi::Function::createFromHostFunction(
            runtime,
            jsi::PropNameID::forAscii(runtime, "setOnMessage"),
            1,
            [=](jsi::Runtime &rt, const jsi::Value &, const jsi::Value *args, size_t count) {
              if (count != 1) {
                throw jsi::JSError(rt, "Expected exactly one argument");
              }

              const jsi::Value &arg = args[0];
              if (!arg.isObject() || !arg.asObject(rt).isFunction(rt)) {
                throw jsi::JSError(rt, "Expected a function as the first argument");
              }

              jsi::Function fn = arg.asObject(rt).asFunction(rt);
              _onMessageSandbox = std::make_shared<jsi::Function>(std::move(fn));

              return jsi::Value::undefined();
            }));

    // Get ErrorUtils
    jsi::Object global = runtime.global();
    jsi::Value errorUtilsVal = global.getProperty(runtime, "ErrorUtils");
    if (!errorUtilsVal.isObject()) {
      throw std::runtime_error("ErrorUtils is not available on global object");
    }

    jsi::Object errorUtils = errorUtilsVal.asObject(runtime);

    std::shared_ptr<jsi::Value> originalHandler = std::make_shared<jsi::Value>(
        errorUtils.getProperty(runtime, "getGlobalHandler").asObject(runtime).asFunction(runtime).call(runtime));

    auto handlerFunc = jsi::Function::createFromHostFunction(
        runtime,
        jsi::PropNameID::forAscii(runtime, "customGlobalErrorHandler"),
        2,
        [=, originalHandler = std::move(originalHandler)](
            jsi::Runtime &rt, const jsi::Value &thisVal, const jsi::Value *args, size_t count) -> jsi::Value {
          if (count < 2) {
            return jsi::Value::undefined();
          }

          if (self.eventEmitter && self.hasOnErrorHandler) {
            const jsi::Object &error = args[0].asObject(rt);
            bool isFatal = args[1].getBool();

            SandboxReactNativeViewEventEmitter::OnError errorEvent = {
                .isFatal = isFatal,
                .name = safeGetStringProperty(rt, error, "name"),
                .message = safeGetStringProperty(rt, error, "message"),
                .stack = safeGetStringProperty(rt, error, "stack")};
            self.eventEmitter->onError(errorEvent);
          } else { // Call the original handler
            if (originalHandler->isObject() && originalHandler->asObject(rt).isFunction(rt)) {
              jsi::Function original = originalHandler->asObject(rt).asFunction(rt);
              original.call(rt, args, count);
            }
          }

          return jsi::Value::undefined();
        });

    // Set the new global error handler
    jsi::Function setHandler =
        errorUtils.getProperty(runtime, "setGlobalHandler").asObject(runtime).asFunction(runtime);
    setHandler.call(runtime, {std::move(handlerFunc)});

    // Disable further setGlobalHandler from sandbox
    stubJsiFunction(runtime, errorUtils, "setGlobalHandler");
  }];
}

#pragma mark - RCTTurboModuleManagerDelegate

- (id<RCTModuleProvider>)getModuleProvider:(const char *)name
{
  NSLog(@"SandboxReactNativeDelegate.getModuleProvider %s", name);
  return _allowedModules.contains(name) ? [super getModuleProvider:name] : nullptr;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const std::string &)name
                                                      jsInvoker:(std::shared_ptr<facebook::react::CallInvoker>)jsInvoker
{
  if (_allowedModules.contains(name)) {
    return [super getTurboModule:name jsInvoker:jsInvoker];
  } else {
    NSLog(
        @"SandboxReactNativeDelegate.getTurboModule: blocking access to C++ TurboModule '%s', returning C++ stub",
        name.c_str());
    // Return C++ stub instead of nullptr
    return std::make_shared<facebook::react::StubTurboModuleCxx>(name, jsInvoker);
  }
}

@end
