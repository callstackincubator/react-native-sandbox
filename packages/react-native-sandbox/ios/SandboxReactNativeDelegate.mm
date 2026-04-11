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

#import <React/RCTBridge+Private.h>
#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTFollyConvert.h>
#import <ReactAppDependencyProvider/RCTAppDependencyProvider.h>
#import <ReactCommon/RCTInteropTurboModule.h>
#import <ReactCommon/RCTTurboModule.h>

#import <objc/runtime.h>

#include <fmt/format.h>
#include "ISandboxAwareModule.h"
#import "RCTSandboxAwareModule.h"
#include "SandboxDelegateWrapper.h"
#include "SandboxRegistry.h"
#import "StubTurboModuleCxx.h"

namespace jsi = facebook::jsi;
namespace TurboModuleConvertUtils = facebook::react::TurboModuleConvertUtils;
using namespace facebook::react;

class SandboxNativeMethodCallInvoker : public NativeMethodCallInvoker {
  dispatch_queue_t methodQueue_;

 public:
  explicit SandboxNativeMethodCallInvoker(dispatch_queue_t methodQueue) : methodQueue_(methodQueue) {}

  void invokeAsync(const std::string &, std::function<void()> &&work) noexcept override
  {
    if (methodQueue_ == RCTJSThread) {
      work();
      return;
    }
    __block auto retainedWork = std::move(work);
    dispatch_async(methodQueue_, ^{
      retainedWork();
    });
  }

  void invokeSync(const std::string &, std::function<void()> &&work) override
  {
    work();
  }
};

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
  std::shared_ptr<rnsandbox::SandboxDelegateWrapper> _delegateWrapper;
  std::set<std::string> _allowedTurboModules;
  std::set<std::string> _allowedOrigins;
  std::map<std::string, std::string> _turboModuleSubstitutions;
  std::string _origin;
  std::string _jsBundleSource;
  NSMutableDictionary<NSString *, id<RCTBridgeModule>> *_substitutedModuleInstances;
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
    _substitutedModuleInstances = [NSMutableDictionary new];
    self.dependencyProvider = [[RCTAppDependencyProvider alloc] init];
  }
  return self;
}

- (void)cleanupResources
{
  _onMessageSandbox.reset();
  _rctInstance = nil;
  _allowedTurboModules.clear();
  _allowedOrigins.clear();
  _turboModuleSubstitutions.clear();
  [_substitutedModuleInstances removeAllObjects];
  if (_delegateWrapper) {
    _delegateWrapper->invalidate();
    _delegateWrapper.reset();
  }
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

  if (!_origin.empty()) {
    auto &registry = rnsandbox::SandboxRegistry::getInstance();
    registry.unregister(_origin);
  }
  if (_delegateWrapper) {
    _delegateWrapper->invalidate();
    _delegateWrapper.reset();
  }

  _origin = origin;

  if (!_origin.empty()) {
    auto &registry = rnsandbox::SandboxRegistry::getInstance();
    _delegateWrapper = std::make_shared<rnsandbox::SandboxDelegateWrapper>(self);
    registry.registerSandbox(_origin, _delegateWrapper, _allowedOrigins);
  }
}

- (void)setJsBundleSource:(std::string)jsBundleSource
{
  _jsBundleSource = jsBundleSource;
}

- (void)setAllowedOrigins:(std::set<std::string>)allowedOrigins
{
  _allowedOrigins = allowedOrigins;

  if (!_origin.empty()) {
    auto &registry = rnsandbox::SandboxRegistry::getInstance();
    if (!_delegateWrapper) {
      _delegateWrapper = std::make_shared<rnsandbox::SandboxDelegateWrapper>(self);
    }
    registry.registerSandbox(_origin, _delegateWrapper, _allowedOrigins);
  }
}

- (void)setAllowedTurboModules:(std::set<std::string>)allowedTurboModules
{
  _allowedTurboModules = allowedTurboModules;
}

- (std::map<std::string, std::string>)turboModuleSubstitutions
{
  return _turboModuleSubstitutions;
}

- (void)setTurboModuleSubstitutions:(std::map<std::string, std::string>)turboModuleSubstitutions
{
  _turboModuleSubstitutions = turboModuleSubstitutions;
}

- (void)dealloc
{
  if (_delegateWrapper) {
    _delegateWrapper->invalidate();
    _delegateWrapper.reset();
  }
  if (!_origin.empty()) {
    auto &registry = rnsandbox::SandboxRegistry::getInstance();
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
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:bundleName];
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
  auto &registry = rnsandbox::SandboxRegistry::getInstance();
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

/**
 * RCTTurboModuleManagerDelegate resolution order (called by RCTTurboModuleManager):
 *
 *  PRIORITY 1 — getTurboModule:jsInvoker:
 *    Called first. Returns a fully constructed C++ TurboModule (shared_ptr).
 *    If non-null, resolution stops here — nothing else is called.
 *    This is the primary path for C++ TurboModules and our ObjC substitution fallback.
 *
 *  PRIORITY 2 — getModuleClassFromName:
 *    Called if getTurboModule returned nullptr. Provides the ObjC class for a module name.
 *    The TurboModuleManager then calls getModuleInstanceFromClass: with this class.
 *
 *  PRIORITY 3 — getModuleInstanceFromClass:
 *    Called with the class from step 2 (or the auto-registered class).
 *    Creates and returns an ObjC module instance. The TurboModuleManager then wraps it
 *    in an ObjCInteropTurboModule internally and sets up its methodQueue via KVC.
 *    NOTE: This path goes through RCTInstance as a weak delegate intermediary, which
 *    can become nil — causing a second unconfigured instance. That's why we prefer
 *    handling ObjC substitutions in getTurboModule:jsInvoker: (priority 1) instead.
 *
 *  PRIORITY 4 — getModuleProvider:
 *    Legacy/alternative path. Called by some internal flows to get a module instance
 *    by name string. Similar role to getModuleInstanceFromClass but name-based.
 */

#pragma mark - RCTTurboModuleManagerDelegate

// PRIORITY 1
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const std::string &)name
                                                      jsInvoker:(std::shared_ptr<facebook::react::CallInvoker>)jsInvoker
{
  auto it = _turboModuleSubstitutions.find(name);
  if (it != _turboModuleSubstitutions.end()) {
    const std::string &resolvedName = it->second;

    // Try C++ TurboModule first (e.g. codegen-generated spec)
    auto cxxModule = [super getTurboModule:resolvedName jsInvoker:jsInvoker];
    if (cxxModule) {
      if (auto sandboxAware = std::dynamic_pointer_cast<rnsandbox::ISandboxAwareModule>(cxxModule)) {
        sandboxAware->configureSandbox({
            .origin = _origin,
            .requestedModuleName = name,
            .resolvedModuleName = resolvedName,
        });
      }
      return cxxModule;
    }

    return [self _createObjCTurboModuleForSubstitution:name resolvedName:resolvedName jsInvoker:jsInvoker];
  }

  if (_allowedTurboModules.contains(name)) {
    return [super getTurboModule:name jsInvoker:jsInvoker];
  }

  return std::make_shared<rnsandbox::StubTurboModuleCxx>(name, jsInvoker);
}

// PRIORITY 2
- (Class)getModuleClassFromName:(const char *)name
{
  std::string nameStr(name);

  auto it = _turboModuleSubstitutions.find(nameStr);
  if (it != _turboModuleSubstitutions.end()) {
    NSString *resolvedName = [NSString stringWithUTF8String:it->second.c_str()];
    for (Class moduleClass in RCTGetModuleClasses()) {
      if ([[moduleClass moduleName] isEqualToString:resolvedName]) {
        return moduleClass;
      }
    }
  }

  return nullptr;
}

// PRIORITY 3
- (id<RCTTurboModule>)getModuleInstanceFromClass:(Class)moduleClass
{
  NSString *moduleName = [moduleClass moduleName];
  if (!moduleName) {
    return nullptr;
  }

  id<RCTBridgeModule> cached = _substitutedModuleInstances[moduleName];
  if (cached) {
    return (id<RCTTurboModule>)cached;
  }

  std::string moduleNameStr = [moduleName UTF8String];
  bool isSubstitutionTarget = false;
  std::string requestedName;

  for (auto &pair : _turboModuleSubstitutions) {
    if (pair.second == moduleNameStr) {
      isSubstitutionTarget = true;
      requestedName = pair.first;
      break;
    }
  }

  if (!isSubstitutionTarget) {
    return nullptr;
  }

  id<RCTBridgeModule> module = [moduleClass new];

  if ([(id)module conformsToProtocol:@protocol(RCTSandboxAwareModule)]) {
    NSString *originNS = [NSString stringWithUTF8String:_origin.c_str()];
    NSString *requestedNameNS = [NSString stringWithUTF8String:requestedName.c_str()];
    [(id<RCTSandboxAwareModule>)module configureSandboxWithOrigin:originNS
                                                    requestedName:requestedNameNS
                                                     resolvedName:moduleName];
  }

  _substitutedModuleInstances[moduleName] = module;
  return (id<RCTTurboModule>)module;
}

// PRIORITY 4
- (id<RCTModuleProvider>)getModuleProvider:(const char *)name
{
  std::string nameStr(name);

  auto it = _turboModuleSubstitutions.find(nameStr);
  if (it != _turboModuleSubstitutions.end()) {
    NSString *resolvedName = [NSString stringWithUTF8String:it->second.c_str()];

    id<RCTBridgeModule> cached = _substitutedModuleInstances[resolvedName];
    if (cached) {
      return (id<RCTModuleProvider>)cached;
    }

    // Try the dependency provider first (for Codegen TurboModules)
    id<RCTModuleProvider> provider = [super getModuleProvider:it->second.c_str()];

    if (!provider) {
      for (Class moduleClass in RCTGetModuleClasses()) {
        if ([[moduleClass moduleName] isEqualToString:resolvedName]) {
          provider = [moduleClass new];
          break;
        }
      }
    }

    if (!provider) {
      return nullptr;
    }

    if ([(id)provider conformsToProtocol:@protocol(RCTSandboxAwareModule)]) {
      NSString *originNS = [NSString stringWithUTF8String:_origin.c_str()];
      NSString *requestedNameNS = [NSString stringWithUTF8String:nameStr.c_str()];
      [(id<RCTSandboxAwareModule>)provider configureSandboxWithOrigin:originNS
                                                        requestedName:requestedNameNS
                                                         resolvedName:resolvedName];
    }

    if ([(id)provider conformsToProtocol:@protocol(RCTBridgeModule)]) {
      _substitutedModuleInstances[resolvedName] = (id<RCTBridgeModule>)provider;
    }

    return provider;
  }

  return _allowedTurboModules.contains(nameStr) ? [super getModuleProvider:name] : nullptr;
}

- (std::shared_ptr<facebook::react::TurboModule>)
    _createObjCTurboModuleForSubstitution:(const std::string &)requestedName
                             resolvedName:(const std::string &)resolvedName
                                jsInvoker:(std::shared_ptr<facebook::react::CallInvoker>)jsInvoker
{
  NSString *resolvedNameNS = [NSString stringWithUTF8String:resolvedName.c_str()];

  id<RCTBridgeModule> cached = _substitutedModuleInstances[resolvedNameNS];
  if (cached && [(id)cached conformsToProtocol:@protocol(RCTTurboModule)]) {
    return [self _wrapObjCModule:cached moduleName:requestedName jsInvoker:jsInvoker];
  }

  Class moduleClass = nil;
  for (Class cls in RCTGetModuleClasses()) {
    if ([[cls moduleName] isEqualToString:resolvedNameNS]) {
      moduleClass = cls;
      break;
    }
  }

  if (!moduleClass) {
    return nullptr;
  }

  id<RCTBridgeModule> instance = [moduleClass new];

  if ([(id)instance conformsToProtocol:@protocol(RCTSandboxAwareModule)]) {
    NSString *originNS = [NSString stringWithUTF8String:_origin.c_str()];
    NSString *requestedNameNS = [NSString stringWithUTF8String:requestedName.c_str()];
    [(id<RCTSandboxAwareModule>)instance configureSandboxWithOrigin:originNS
                                                      requestedName:requestedNameNS
                                                       resolvedName:resolvedNameNS];
  }

  _substitutedModuleInstances[resolvedNameNS] = instance;

  if (![(id)instance conformsToProtocol:@protocol(RCTTurboModule)]) {
    return nullptr;
  }

  return [self _wrapObjCModule:instance moduleName:requestedName jsInvoker:jsInvoker];
}

- (std::shared_ptr<facebook::react::TurboModule>)_wrapObjCModule:(id<RCTBridgeModule>)instance
                                                      moduleName:(const std::string &)moduleName
                                                       jsInvoker:
                                                           (std::shared_ptr<facebook::react::CallInvoker>)jsInvoker
{
  dispatch_queue_t methodQueue = nil;
  BOOL hasMethodQueueGetter = [instance respondsToSelector:@selector(methodQueue)];
  if (hasMethodQueueGetter) {
    methodQueue = [instance methodQueue];
  }

  if (!methodQueue) {
    NSString *label = [NSString stringWithFormat:@"com.sandbox.%s", moduleName.c_str()];
    methodQueue = dispatch_queue_create(label.UTF8String, DISPATCH_QUEUE_SERIAL);

    if (hasMethodQueueGetter) {
      @try {
        [(id)instance setValue:methodQueue forKey:@"methodQueue"];
      } @catch (NSException *exception) {
        RCTLogError(@"[Sandbox] Failed to set methodQueue on module '%s': %@", moduleName.c_str(), exception.reason);
      }
    }
  }

  auto nativeInvoker = std::make_shared<SandboxNativeMethodCallInvoker>(methodQueue);

  facebook::react::ObjCTurboModule::InitParams params = {
      .moduleName = moduleName,
      .instance = instance,
      .jsInvoker = jsInvoker,
      .nativeMethodCallInvoker = nativeInvoker,
      .isSyncModule = methodQueue == RCTJSThread,
      .shouldVoidMethodsExecuteSync = false,
  };
  return [(id<RCTTurboModule>)instance getTurboModule:params];
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
