//
//  SandboxReactNativeDelegate.mm
//  react-native-sandbox
//
//  Created by Aliaksandr Babrykovich on 25/06/2025.
//

#import "SandboxReactNativeDelegate.h"

#include <jsi/JSIDynamic.h>
#include <jsi/decorator.h>
#include <react/utils/jsi-utils.h>
#include <map>
#include <memory>
#include <mutex>

#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTFollyConvert.h>
#import <ReactAppDependencyProvider/RCTAppDependencyProvider.h>
#import <ReactCommon/RCTTurboModule.h>

#import <objc/runtime.h>

#import "SandboxRegistry.h"
#import "StubTurboModuleCxx.h"

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

- (void)cleanupResources;

- (jsi::Function)createPostMessageFunction:(jsi::Runtime &)runtime;
- (jsi::Function)createSetOnMessageFunction:(jsi::Runtime &)runtime;
- (void)setupErrorHandler:(jsi::Runtime &)runtime;

@end

@implementation SandboxReactNativeDelegate

@synthesize allowedOrigins = _allowedOrigins;

// Note: Registry functionality has been moved to SandboxRegistry class
// This class now focuses solely on delegate responsibilities

#pragma mark - Instance Methods

- (void)setSandboxId:(NSString *)sandboxId
{
  if ([sandboxId isEqual:_sandboxId]) {
    return;
  }

  // Unregister old ID if it exists
  if (_sandboxId) {
    [[SandboxRegistry shared] unregister:_sandboxId];
  }

  // Set new ID
  _sandboxId = [sandboxId copy];

  // Register new ID if it's not nil
  if (_sandboxId) {
    [[SandboxRegistry shared] registerSandbox:_sandboxId delegate:self allowedOrigins:self.allowedOrigins];
  }
}

- (void)setAllowedTurboModules:(NSArray<NSString *> *)allowedTurboModules
{
  _allowedModules.clear();
  for (NSString *s in allowedTurboModules) {
    _allowedModules.insert([s UTF8String]);
  }
}

- (void)setAllowedOrigins:(NSArray<NSString *> *)allowedOrigins
{
  _allowedOrigins = [allowedOrigins copy];

  // Re-register with new allowedOrigins if sandboxId is set
  if (self.sandboxId) {
    [[SandboxRegistry shared] registerSandbox:self.sandboxId delegate:self allowedOrigins:self.allowedOrigins];
  }
}

- (instancetype)init
{
  if (self = [super init]) {
    _hasOnMessageHandler = NO;
    _hasOnErrorHandler = NO;
    self.dependencyProvider = [[RCTAppDependencyProvider alloc] init];
  }
  return self;
}

- (void)cleanupResources
{
  _onMessageSandbox.reset();
  _rctInstance = nil;
  _allowedModules.clear();
}

- (void)dealloc
{
  if (self.sandboxId) {
    [[SandboxRegistry shared] unregister:self.sandboxId];
  } else {
    [self cleanupResources];
  }
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
  return [self bundleURL];
}

- (NSURL *)bundleURL
{
  if (!self.jsBundleSource) {
    return nil;
  }

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
  if (!_onMessageSandbox || !_rctInstance) {
    return;
  }

  [_rctInstance callFunctionOnBufferedRuntimeExecutor:[=](jsi::Runtime &runtime) {
    try {
      // Validate runtime before any JSI operations
      runtime.global(); // Test if runtime is accessible

      // Double-check the JSI function is still valid
      if (!_onMessageSandbox) {
        return;
      }

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
            .isFatal = false, .name = "RuntimeError", .message = e.what(), .stack = ""};
        self.eventEmitter->onError(errorEvent);
      }
    } catch (...) {
      NSLog(@"[SandboxReactNativeDelegate] Runtime invalid during postMessage for sandbox %@", self.sandboxId);
    }
  }];
}

- (BOOL)routeMessage:(NSString *)message toSandbox:(NSString *)targetId
{
  id target = [[SandboxRegistry shared] find:targetId];
  if (!target || ![target respondsToSelector:@selector(postMessage:)]) {
    return NO;
  }

  // Check if the current sandbox is permitted to send messages to the target
  if (![[SandboxRegistry shared] isPermittedFrom:self.sandboxId to:targetId]) {
    if (self.eventEmitter && self.hasOnErrorHandler) {
      NSString *errorMessageNS =
          [NSString stringWithFormat:@"Access denied: Sandbox '%@' is not permitted to send messages to '%@'",
                                     self.sandboxId,
                                     targetId];
      std::string errorMessage = [errorMessageNS UTF8String];
      SandboxReactNativeViewEventEmitter::OnError errorEvent = {
          .isFatal = false, .name = "AccessDeniedError", .message = errorMessage, .stack = ""};
      self.eventEmitter->onError(errorEvent);
    }
    return NO;
  }

  [target postMessage:message];
  return YES;
}

- (void)hostDidStart:(RCTHost *)host
{
  if (!host) {
    return;
  }

  // Safely clear any existing JSI function and instance before new runtime setup
  // This prevents crash on reload when old function is tied to invalid runtime
  _onMessageSandbox.reset();
  _onMessageSandbox = nullptr;

  // Clear old instance reference before setting new one
  _rctInstance = nil;

  Ivar ivar = class_getInstanceVariable([host class], "_instance");
  _rctInstance = object_getIvar(host, ivar);

  if (!_rctInstance) {
    return;
  }

  [_rctInstance callFunctionOnBufferedRuntimeExecutor:[=](jsi::Runtime &runtime) {
    facebook::react::defineReadOnlyGlobal(runtime, "postMessage", [self createPostMessageFunction:runtime]);
    facebook::react::defineReadOnlyGlobal(runtime, "setOnMessage", [self createSetOnMessageFunction:runtime]);
    [self setupErrorHandler:runtime];
  }];
}

#pragma mark - RCTTurboModuleManagerDelegate

- (id<RCTModuleProvider>)getModuleProvider:(const char *)name
{
  return _allowedModules.contains(name) ? [super getModuleProvider:name] : nullptr;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const std::string &)name
                                                      jsInvoker:(std::shared_ptr<facebook::react::CallInvoker>)jsInvoker
{
  if (_allowedModules.contains(name)) {
    return [super getTurboModule:name jsInvoker:jsInvoker];
  } else {
    // Return C++ stub instead of nullptr
    return std::make_shared<facebook::react::StubTurboModuleCxx>(name, jsInvoker);
  }
}

- (jsi::Function)createPostMessageFunction:(jsi::Runtime &)runtime
{
  return jsi::Function::createFromHostFunction(
      runtime,
      jsi::PropNameID::forAscii(runtime, "postMessage"),
      2, // Updated to accept up to 2 arguments
      [=](jsi::Runtime &rt, const jsi::Value &, const jsi::Value *args, size_t count) {
        // Validate runtime before any JSI operations
        try {
          rt.global(); // Test if runtime is accessible
        } catch (...) {
          return jsi::Value::undefined();
        }

        if (count < 1 || count > 2) {
          throw jsi::JSError(rt, "Expected 1 or 2 arguments: postMessage(message, targetOrigin?)");
        }

        const jsi::Value &messageArg = args[0];
        if (!messageArg.isObject()) {
          throw jsi::JSError(rt, "Expected an object as the first argument");
        }

        // Check if targetOrigin is provided
        if (count == 2 && !args[1].isNull() && !args[1].isUndefined()) {
          const jsi::Value &targetOriginArg = args[1];
          if (!targetOriginArg.isString()) {
            throw jsi::JSError(rt, "Expected a string as the second argument (targetOrigin)");
          }

          std::string targetOrigin = targetOriginArg.getString(rt).utf8(rt);
          NSString *targetOriginNS = [NSString stringWithUTF8String:targetOrigin.c_str()];

          // Prevent self-targeting
          if (self.sandboxId && [self.sandboxId isEqualToString:targetOriginNS]) {
            if (self.eventEmitter && self.hasOnErrorHandler) {
              NSString *errorMessageNS =
                  [NSString stringWithFormat:@"Cannot send message to self (sandbox '%@')", targetOriginNS];
              std::string errorMessage = [errorMessageNS UTF8String];
              SandboxReactNativeViewEventEmitter::OnError errorEvent = {
                  .isFatal = false, .name = "SelfTargetingError", .message = errorMessage, .stack = ""};
              self.eventEmitter->onError(errorEvent);
            } else {
              // Fallback: throw JSError if no error handler
              throw jsi::JSError(rt, ("Cannot send message to self (sandbox '" + targetOrigin + "')").c_str());
            }
            return jsi::Value::undefined();
          }

          // Convert message to JSON string
          jsi::Object jsonObject = rt.global().getPropertyAsObject(rt, "JSON");
          jsi::Function jsonStringify = jsonObject.getPropertyAsFunction(rt, "stringify");
          jsi::Value jsonResult = jsonStringify.call(rt, messageArg);
          std::string messageJson = jsonResult.getString(rt).utf8(rt);
          NSString *messageNS = [NSString stringWithUTF8String:messageJson.c_str()];

          // Route message to specific sandbox
          BOOL success = [self routeMessage:messageNS toSandbox:targetOriginNS];
          if (!success) {
            // Target sandbox doesn't exist - trigger error event
            if (self.eventEmitter && self.hasOnErrorHandler) {
              NSString *errorMessageNS = [NSString stringWithFormat:@"Target sandbox '%@' not found", targetOriginNS];
              std::string errorMessage = [errorMessageNS UTF8String];
              SandboxReactNativeViewEventEmitter::OnError errorEvent = {
                  .isFatal = false, .name = "SandboxRoutingError", .message = errorMessage, .stack = ""};
              self.eventEmitter->onError(errorEvent);
            } else {
              // Fallback: throw JSError if no error handler
              NSString *errorMessageNS = [NSString stringWithFormat:@"Target sandbox '%@' not found", targetOriginNS];
              std::string errorMessage = [errorMessageNS UTF8String];
              throw jsi::JSError(rt, errorMessage.c_str());
            }
          }
        } else {
          // targetOrigin is undefined/null - route to host (backward compatibility)
          if (self.eventEmitter && self.hasOnMessageHandler) {
            SandboxReactNativeViewEventEmitter::OnMessage messageEvent = {.data = jsi::dynamicFromValue(rt, args[0])};
            self.eventEmitter->onMessage(messageEvent);
          }
        }

        return jsi::Value::undefined();
      });
}

- (jsi::Function)createSetOnMessageFunction:(jsi::Runtime &)runtime
{
  return jsi::Function::createFromHostFunction(
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

        // Safely reset existing function before assigning new one
        // This prevents crash if old function is tied to invalid runtime
        _onMessageSandbox.reset();
        _onMessageSandbox = std::make_shared<jsi::Function>(std::move(fn));

        return jsi::Value::undefined();
      });
}

- (void)setupErrorHandler:(jsi::Runtime &)runtime
{
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
  jsi::Function setHandler = errorUtils.getProperty(runtime, "setGlobalHandler").asObject(runtime).asFunction(runtime);
  setHandler.call(runtime, {std::move(handlerFunc)});

  // Disable further setGlobalHandler from sandbox
  stubJsiFunction(runtime, errorUtils, "setGlobalHandler");
}

@end
