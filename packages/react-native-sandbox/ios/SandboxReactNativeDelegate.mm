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
#include <map>
#include <memory>
#include <mutex>

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

@end

@implementation SandboxReactNativeDelegate

#pragma mark - Static Registry Implementation

// Global static registry for sandbox communication
static std::map<std::string, SandboxReactNativeDelegate *> _sandboxRegistry;
static std::mutex _registryMutex;

+ (void)registerSandbox:(NSString *)sandboxId delegate:(SandboxReactNativeDelegate *)delegate
{
  if (!sandboxId || !delegate) {
    NSLog(@"[SandboxRegistry] Cannot register sandbox: sandboxId=%@ delegate=%@", sandboxId, delegate);
    return;
  }

  std::lock_guard<std::mutex> lock(_registryMutex);
  std::string cppSandboxId = [sandboxId UTF8String];

  if (_sandboxRegistry.find(cppSandboxId) != _sandboxRegistry.end()) {
    NSLog(@"[SandboxRegistry] Warning: Overwriting existing sandbox with ID: %@", sandboxId);
  }

  _sandboxRegistry[cppSandboxId] = delegate;
  // delegate.sandboxId = sandboxId;

  NSLog(@"[SandboxRegistry] Registered sandbox: %@ (total: %zu)", sandboxId, _sandboxRegistry.size());
}

+ (void)unregisterSandbox:(NSString *)sandboxId
{
  if (!sandboxId) {
    return;
  }

  std::lock_guard<std::mutex> lock(_registryMutex);
  std::string cppSandboxId = [sandboxId UTF8String];

  auto it = _sandboxRegistry.find(cppSandboxId);
  if (it != _sandboxRegistry.end()) {
    it->second.sandboxId = nil;
    _sandboxRegistry.erase(it);
    NSLog(@"[SandboxRegistry] Unregistered sandbox: %@ (total: %zu)", sandboxId, _sandboxRegistry.size());
  }
}

+ (nullable SandboxReactNativeDelegate *)getSandbox:(NSString *)sandboxId
{
  if (!sandboxId) {
    return nil;
  }

  std::lock_guard<std::mutex> lock(_registryMutex);
  std::string cppSandboxId = [sandboxId UTF8String];

  auto it = _sandboxRegistry.find(cppSandboxId);
  if (it != _sandboxRegistry.end()) {
    return it->second;
  }

  return nil;
}

+ (BOOL)routeMessage:(NSString *)message toSandbox:(NSString *)targetId
{
  SandboxReactNativeDelegate *target = [self getSandbox:targetId];
  if (!target) {
    NSLog(@"[SandboxRegistry] Cannot route message: target sandbox '%@' not found", targetId);
    return NO;
  }

  [target postMessage:message];
  NSLog(@"[SandboxRegistry] Routed message to sandbox: %@", targetId);
  return YES;
}

#pragma mark - Instance Methods

- (void)setSandboxId:(NSString *)sandboxId
{
  if ([sandboxId isEqual:_sandboxId]) {
    return;
  }

  // Unregister old ID if it exists
  if (_sandboxId) {
    [SandboxReactNativeDelegate unregisterSandbox:_sandboxId];
  }

  // Set new ID
  _sandboxId = [sandboxId copy];

  // Register new ID if it's not nil
  if (_sandboxId) {
    [SandboxReactNativeDelegate registerSandbox:_sandboxId delegate:self];
  }
}

- (void)setAllowedTurboModules:(NSArray<NSString *> *)allowedTurboModules
{
  _allowedModules.clear();
  for (NSString *s in allowedTurboModules) {
    _allowedModules.insert([s UTF8String]);
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

- (void)dealloc
{
  // Auto-unregister when delegate is deallocated
  if (self.sandboxId) {
    [SandboxReactNativeDelegate unregisterSandbox:self.sandboxId];
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
  if (!_onMessageSandbox) {
    return;
  }

  [_rctInstance callFunctionOnBufferedRuntimeExecutor:[=](jsi::Runtime &runtime) {
    try {
      // Validate runtime before any JSI operations
      runtime.global(); // Test if runtime is accessible

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

- (BOOL)isCommunicationReady
{
  BOOL hasEventEmitter = (self.eventEmitter != nullptr);
  BOOL hasMessageSandbox = (_onMessageSandbox != nullptr);
  BOOL isRegistered = (self.sandboxId != nil);

  NSLog(
      @"[SandboxReactNativeDelegate] Communication status for %@: eventEmitter=%@, messageSandbox=%@, registered=%@",
      self.sandboxId ?: @"(nil)",
      hasEventEmitter ? @"YES" : @"NO",
      hasMessageSandbox ? @"YES" : @"NO",
      isRegistered ? @"YES" : @"NO");

  return hasEventEmitter && hasMessageSandbox && isRegistered;
}

- (void)hostDidStart:(RCTHost *)host
{
  // Safely clear any existing JSI function before new runtime setup
  // This prevents crash on reload when old function is tied to invalid runtime
  try {
    _onMessageSandbox = nullptr;
  } catch (...) {
    // Old function destructor might crash if tied to invalid runtime
    NSLog(
        @"[SandboxReactNativeDelegate] Warning: Exception while clearing old JSI function for sandbox %@",
        self.sandboxId);
  }

  Ivar ivar = class_getInstanceVariable([host class], "_instance");
  _rctInstance = object_getIvar(host, ivar);

  [_rctInstance callFunctionOnBufferedRuntimeExecutor:[=](jsi::Runtime &runtime) {
    facebook::react::defineReadOnlyGlobal(
        runtime,
        "postMessage",
        jsi::Function::createFromHostFunction(
            runtime,
            jsi::PropNameID::forAscii(runtime, "postMessage"),
            2, // Updated to accept up to 2 arguments
            [=](jsi::Runtime &rt, const jsi::Value &, const jsi::Value *args, size_t count) {
              // Validate runtime before any JSI operations
              try {
                rt.global(); // Test if runtime is accessible
              } catch (...) {
                NSLog(@"[SandboxReactNativeDelegate] Runtime invalid in postMessage for sandbox %@", self.sandboxId);
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
                    std::string errorMessage = "Cannot send message to self (sandbox '" + targetOrigin + "')";
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
                BOOL success = [SandboxReactNativeDelegate routeMessage:messageNS toSandbox:targetOriginNS];
                if (!success) {
                  // Target sandbox doesn't exist - trigger error event
                  if (self.eventEmitter && self.hasOnErrorHandler) {
                    std::string errorMessage = "Target sandbox '" + targetOrigin + "' not found";
                    SandboxReactNativeViewEventEmitter::OnError errorEvent = {
                        .isFatal = false, .name = "SandboxRoutingError", .message = errorMessage, .stack = ""};
                    self.eventEmitter->onError(errorEvent);
                  } else {
                    // Fallback: throw JSError if no error handler
                    throw jsi::JSError(rt, ("Target sandbox '" + targetOrigin + "' not found").c_str());
                  }
                }
              } else {
                // targetOrigin is undefined/null - route to host (backward compatibility)
                if (self.eventEmitter && self.hasOnMessageHandler) {
                  SandboxReactNativeViewEventEmitter::OnMessage messageEvent = {
                      .data = jsi::dynamicFromValue(rt, args[0])};
                  self.eventEmitter->onMessage(messageEvent);
                } else {
                  // Log why message to host failed
                  if (!self.eventEmitter) {
                    NSLog(
                        @"[SandboxReactNativeDelegate] Cannot send message to host: eventEmitter is nullptr for sandbox %@",
                        self.sandboxId);
                  } else if (!self.hasOnMessageHandler) {
                    NSLog(
                        @"[SandboxReactNativeDelegate] Cannot send message to host: no message handler for sandbox %@",
                        self.sandboxId);
                  }
                }
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

              NSLog(@"[SandboxReactNativeDelegate] setOnMessage for sandbox %@", self.sandboxId);

              jsi::Function fn = arg.asObject(rt).asFunction(rt);

              // Safely reset existing function before assigning new one
              // This prevents crash if old function is tied to invalid runtime
              _onMessageSandbox.reset();
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
