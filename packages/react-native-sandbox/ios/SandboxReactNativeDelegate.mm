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
#ifndef EXPO_MODULE
#import <ReactAppDependencyProvider/RCTAppDependencyProvider.h>
#endif
#import <ReactCommon/RCTTurboModule.h>

#import <objc/runtime.h>

#include <fmt/format.h>
#include "SandboxDelegateWrapper.h"
#include "SandboxRegistry.h"
#import "StubTurboModuleCxx.h"

// Conditional imports for Expo support
#ifdef EXPO_MODULE
#import <ExpoModulesCore/EXAppDefines.h>
#import <ExpoModulesCore/ExpoModulesCore.h>
#endif

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
  std::set<std::string> _allowedTurboModules;
  std::set<std::string> _allowedOrigins;
  std::string _origin;
  std::string _jsBundleSource;
}

- (void)cleanupResources;

- (jsi::Function)createPostMessageFunction:(jsi::Runtime &)runtime;
- (jsi::Function)createSetOnMessageFunction:(jsi::Runtime &)runtime;
- (void)setupErrorHandler:(jsi::Runtime &)runtime;

@end

@implementation SandboxReactNativeDelegate

// Note: Registry functionality has been moved to SandboxRegistry class
// This class now focuses solely on delegate responsibilities

#pragma mark - Instance Methods

- (instancetype)init
{
  if (self = [super init]) {
    _hasOnMessageHandler = NO;
    _hasOnErrorHandler = NO;

#ifdef EXPO_MODULE
    // Expo-specific initialization
    // Note: Expo may handle dependency provider differently
    NSLog(@"[SandboxReactNativeDelegate] Initialized for Expo environment");
#else
    // React Native initialization
    self.dependencyProvider = [[RCTAppDependencyProvider alloc] init];
#endif
  }
  return self;
}

- (void)cleanupResources
{
  _onMessageSandbox.reset();
  _rctInstance = nil;
  _allowedTurboModules.clear();
  _allowedOrigins.clear();
}

#pragma mark - C++ Property Getters

- (std::string)origin
{
  return _origin;
}

- (std::string)jsBundleSource
{
  return _jsBundleSource;
}

- (std::set<std::string>)allowedOrigins
{
  return _allowedOrigins;
}

- (std::set<std::string>)allowedTurboModules
{
  return _allowedTurboModules;
}

- (void)setOrigin:(std::string)origin
{
  if (_origin == origin) {
    return;
  }

  // Unregister old origin if it exists
  if (!_origin.empty()) {
    auto &registry = SandboxRegistry::getInstance();
    registry.unregister(_origin);
  }

  // Set new origin
  _origin = origin;

  // Register new origin if it's not empty
  if (!_origin.empty()) {
    auto &registry = SandboxRegistry::getInstance();
    auto wrapper = std::make_shared<SandboxDelegateWrapper>(self);
    registry.registerSandbox(_origin, wrapper, _allowedOrigins);
  }
}

- (void)setJsBundleSource:(std::string)jsBundleSource
{
  _jsBundleSource = jsBundleSource;
}

- (void)setAllowedOrigins:(std::set<std::string>)allowedOrigins
{
  _allowedOrigins = allowedOrigins;

  // Re-register with new allowedOrigins if origin is set
  if (!_origin.empty()) {
    auto &registry = SandboxRegistry::getInstance();
    auto wrapper = std::make_shared<SandboxDelegateWrapper>(self);
    registry.registerSandbox(_origin, wrapper, _allowedOrigins);
  }
}

- (void)setAllowedTurboModules:(std::set<std::string>)allowedTurboModules
{
  _allowedTurboModules = allowedTurboModules;
}

- (void)dealloc
{
  if (!_origin.empty()) {
    auto &registry = SandboxRegistry::getInstance();
    registry.unregister(_origin);
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
  if (_jsBundleSource.empty()) {
    return nil;
  }

  NSString *jsBundleSourceNS = [NSString stringWithUTF8String:_jsBundleSource.c_str()];
  NSURL *url = [NSURL URLWithString:jsBundleSourceNS];
  if (url && url.scheme) {
    return url;
  }

  if ([jsBundleSourceNS hasSuffix:@".jsbundle"]) {
    return [[NSBundle mainBundle] URLForResource:jsBundleSourceNS withExtension:nil];
  }

  NSString *bundleName =
      [jsBundleSourceNS hasSuffix:@".bundle"] ? [jsBundleSourceNS stringByDeletingPathExtension] : jsBundleSourceNS;
#ifdef EXPO_MODULE
  // Expo-specific bundle URL handling
  // Expo may have different bundle URL provider
  return [[NSBundle mainBundle] URLForResource:bundleName withExtension:@"bundle"];
#else
  // React Native bundle URL handling
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:bundleName];
#endif
}

- (void)postMessage:(const std::string &)message
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

      jsi::Value parsedValue = runtime.global()
                                   .getPropertyAsObject(runtime, "JSON")
                                   .getPropertyAsFunction(runtime, "parse")
                                   .call(runtime, jsi::String::createFromUtf8(runtime, message));

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
      NSLog(@"[SandboxReactNativeDelegate] Runtime invalid during postMessage for sandbox %s", _origin.c_str());
    }
  }];
}

- (bool)routeMessage:(const std::string &)message toSandbox:(const std::string &)targetId
{
  auto &registry = SandboxRegistry::getInstance();
  auto target = registry.find(targetId);
  if (!target) {
    return false;
  }

  // Check if the current sandbox is permitted to send messages to the target
  if (!registry.isPermittedFrom(_origin, targetId)) {
    if (self.eventEmitter && self.hasOnErrorHandler) {
      std::string errorMessage =
          fmt::format("Access denied: Sandbox '{}' is not permitted to send messages to '{}'", _origin, targetId);
      SandboxReactNativeViewEventEmitter::OnError errorEvent = {
          .isFatal = false, .name = "AccessDeniedError", .message = errorMessage, .stack = ""};
      self.eventEmitter->onError(errorEvent);
    }
    return false;
  }

  target->postMessage(message);
  return true;
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
  return _allowedTurboModules.contains(name) ? [super getModuleProvider:name] : nullptr;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const std::string &)name
                                                      jsInvoker:(std::shared_ptr<facebook::react::CallInvoker>)jsInvoker
{
  if (_allowedTurboModules.contains(name)) {
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

          // Prevent self-targeting
          if (_origin == targetOrigin) {
            if (self.eventEmitter && self.hasOnErrorHandler) {
              std::string errorMessage = fmt::format("Cannot send message to self (sandbox '{}')", targetOrigin);
              SandboxReactNativeViewEventEmitter::OnError errorEvent = {
                  .isFatal = false, .name = "SelfTargetingError", .message = errorMessage, .stack = ""};
              self.eventEmitter->onError(errorEvent);
            } else {
              // Fallback: throw JSError if no error handler
              throw jsi::JSError(rt, fmt::format("Cannot send message to self (sandbox '{}')", targetOrigin).c_str());
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
          BOOL success = [self routeMessage:messageJson toSandbox:targetOrigin];
          if (!success) {
            // Target sandbox doesn't exist - trigger error event
            if (self.eventEmitter && self.hasOnErrorHandler) {
              std::string errorMessage = fmt::format("Target sandbox '{}' not found", targetOrigin);
              SandboxReactNativeViewEventEmitter::OnError errorEvent = {
                  .isFatal = false, .name = "SandboxRoutingError", .message = errorMessage, .stack = ""};
              self.eventEmitter->onError(errorEvent);
            } else {
              // Fallback: throw JSError if no error handler
              std::string errorMessage = fmt::format("Target sandbox '{}' not found", targetOrigin);
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
