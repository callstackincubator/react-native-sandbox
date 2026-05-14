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
#include <unordered_map>

#import <React/RCTBridge+Private.h>
#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTFollyConvert.h>
#import <ReactAppDependencyProvider/RCTAppDependencyProvider.h>
#import <ReactCommon/RCTInteropTurboModule.h>
#import <ReactCommon/RCTTurboModule.h>
#include <folly/json.h>

#import <objc/runtime.h>

#include <fmt/format.h>
#include "ISandboxAwareModule.h"
#import "RCTSandboxAwareModule.h"
#include "SandboxDelegateWrapper.h"
#include "SandboxLogBox.h"
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
  // Per-surface message callbacks keyed by delegate ID.
  // When a sandbox uses useSurfaceMessaging, its setOnMessage registers here
  // so each surface gets its own listener even in a shared VM.
  std::unordered_map<std::string, std::shared_ptr<jsi::Function>> _surfaceMessageCallbacks;
  std::shared_ptr<rnsandbox::SandboxDelegateWrapper> _delegateWrapper;
  std::set<std::string> _allowedTurboModules;
  std::set<std::string> _allowedOrigins;
  std::map<std::string, std::string> _turboModuleSubstitutions;
  std::string _origin;
  std::string _jsBundleSource;
  NSMutableDictionary<NSString *, id<RCTBridgeModule>> *_substitutedModuleInstances;
  NSMutableArray<NSDictionary *> *_pendingHostMessages;
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
    _pendingHostMessages = [NSMutableArray new];
    self.dependencyProvider = [[RCTAppDependencyProvider alloc] init];
  }
  return self;
}

- (void)cleanupResources
{
  _onMessageSandbox.reset();
  _surfaceMessageCallbacks.clear();
  _rctInstance = nil;
  _allowedTurboModules.clear();
  _allowedOrigins.clear();
  _turboModuleSubstitutions.clear();
  [_substitutedModuleInstances removeAllObjects];
  @synchronized(_pendingHostMessages) {
    [_pendingHostMessages removeAllObjects];
  }
  if (_delegateWrapper) {
    _delegateWrapper->invalidate();
    _delegateWrapper.reset();
  }
}

- (void)flushPendingHostMessages
{
  if (!self.eventEmitter || !self.hasOnMessageHandler) {
    return;
  }

  NSArray<NSDictionary *> *messages;
  @synchronized(_pendingHostMessages) {
    if (_pendingHostMessages.count == 0) {
      return;
    }
    messages = [_pendingHostMessages copy];
    [_pendingHostMessages removeAllObjects];
  }

  for (NSDictionary *msg in messages) {
    NSString *dataStr = msg[@"data"];
    if (dataStr) {
      folly::dynamic parsed = folly::parseJson([dataStr UTF8String]);
      SandboxReactNativeViewEventEmitter::OnMessage messageEvent = {.data = parsed};
      self.eventEmitter->onMessage(messageEvent);
    }
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
    if (_delegateWrapper) {
      registry.unregisterDelegate(_origin, _delegateWrapper);
    }
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

- (void)ensureRegistered
{
  if (_origin.empty()) {
    return;
  }
  // Check the registry directly rather than relying on _delegateWrapper,
  // since registry.unregister() removes the entry without invalidating the wrapper.
  auto &registry = rnsandbox::SandboxRegistry::getInstance();
  auto existing = registry.findAll(_origin);
  bool isRegistered = false;
  for (const auto &d : existing) {
    if (_delegateWrapper && d == _delegateWrapper) {
      isRegistered = true;
      break;
    }
  }
  if (!isRegistered) {
    if (_delegateWrapper) {
      _delegateWrapper->invalidate();
      _delegateWrapper.reset();
    }
    _delegateWrapper = std::make_shared<rnsandbox::SandboxDelegateWrapper>(self);
    registry.registerSandbox(_origin, _delegateWrapper, _allowedOrigins);
  }
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
    if (!_origin.empty()) {
      auto &registry = rnsandbox::SandboxRegistry::getInstance();
      registry.unregisterDelegate(_origin, _delegateWrapper);
    }
    _delegateWrapper->invalidate();
    _delegateWrapper.reset();
  } else if (_origin.empty()) {
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

  // jsBundleSource can be either:
  //   1. A bare resource name (e.g. "sandbox") — no extension, resolved by
  //      RCTBundleURLProvider in dev, or as "sandbox.jsbundle" in release.
  //   2. A full filename with extension (e.g. "sandbox.jsbundle") — looked up
  //      directly via URLForResource:withExtension:nil.
  // The two-step lookup below handles both cases without requiring callers to
  // know which form they're using.
  if ([jsBundleSourceNS hasSuffix:@".jsbundle"]) {
    // Full filename provided — look it up directly (step 1 of 2).
    return [[NSBundle mainBundle] URLForResource:jsBundleSourceNS withExtension:nil];
  }

  // Bare name provided — try appending .jsbundle for Release builds (step 2 of 2).
  NSURL *prebuiltURL = [[NSBundle mainBundle] URLForResource:jsBundleSourceNS withExtension:@"jsbundle"];
  if (prebuiltURL) {
    return prebuiltURL;
  }

  NSString *bundleName =
      [jsBundleSourceNS hasSuffix:@".bundle"] ? [jsBundleSourceNS stringByDeletingPathExtension] : jsBundleSourceNS;
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:bundleName];
}

- (void)postMessage:(const std::string &)message
{
  bool hasAnyCallback = _onMessageSandbox || !_surfaceMessageCallbacks.empty();
  if (!hasAnyCallback || !_rctInstance) {
    return;
  }

  [_rctInstance callFunctionOnBufferedRuntimeExecutor:[=](jsi::Runtime &runtime) {
    try {
      // Validate runtime before any JSI operations
      runtime.global(); // Test if runtime is accessible

      jsi::Value parsedValue = runtime.global()
                                   .getPropertyAsObject(runtime, "JSON")
                                   .getPropertyAsFunction(runtime, "parse")
                                   .call(runtime, jsi::String::createFromUtf8(runtime, message));

      // Invoke the legacy shared callback (if any)
      if (_onMessageSandbox) {
        _onMessageSandbox->call(runtime, parsedValue);
      }

      // Invoke all per-surface callbacks
      for (auto &[id, cb] : _surfaceMessageCallbacks) {
        if (cb) {
          cb->call(runtime, parsedValue);
        }
      }
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

  // Check if target exists before checking permissions
  auto targets = registry.findAll(targetId);
  if (targets.empty()) {
    return false;
  }

  // Enforce allowedOrigins access control
  if (!registry.isPermittedFrom(_origin, targetId)) {
    [self postErrorWithName:"AccessDeniedError"
                    message:fmt::format(
                                "Access denied: Sandbox '{}' is not permitted to send messages to '{}'",
                                _origin,
                                targetId)
                      stack:""
                    isFatal:false];
    return true; // Error already handled, don't emit SandboxRoutingError
  }

  for (auto &target : targets) {
    target->postMessage(message);
  }
  return true;
}

- (void)postErrorWithName:(const std::string &)name
                  message:(const std::string &)message
                    stack:(const std::string &)stack
                  isFatal:(bool)isFatal
{
  if (!self.eventEmitter || !self.hasOnErrorHandler) {
    return;
  }
  SandboxReactNativeViewEventEmitter::OnError errorEvent = {
      .isFatal = isFatal, .name = name, .message = message, .stack = stack};
  self.eventEmitter->onError(errorEvent);
}

- (void)hostDidStart:(RCTHost *)host
{
  if (!host) {
    return;
  }

  // The old _onMessageSandbox may hold a jsi::Function tied to a now-dead
  // runtime. Calling reset()/~Function() would access the dead runtime and
  // crash (SIGSEGV in jsi::Pointer::~Pointer). Instead, release ownership
  // without invoking the destructor — the runtime already freed the backing
  // memory, so this is an intentional leak of the shared_ptr control block
  // only (~32 bytes per reload, reclaimed at process exit).
  //
  // The leaked pointer is appended to sLeakedJsiFunctions so that memory
  // analysis tools (Leaks, ASan) see an owned reference rather than an
  // unreferenced allocation. Without this, each reload would appear as a
  // phantom leak in profiling sessions.
  if (_onMessageSandbox) {
    static NSMutableArray *sLeakedJsiFunctions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sLeakedJsiFunctions = [NSMutableArray new];
    });
    auto *leaked = new std::shared_ptr<jsi::Function>(std::move(_onMessageSandbox));
    [sLeakedJsiFunctions addObject:[NSValue valueWithPointer:leaked]];
    _onMessageSandbox = nullptr;
  }

  // Same treatment for per-surface callbacks
  for (auto &[id, cb] : _surfaceMessageCallbacks) {
    if (cb) {
      [[maybe_unused]] auto leaked = new std::shared_ptr<jsi::Function>(std::move(cb));
    }
  }
  _surfaceMessageCallbacks.clear();

  _rctInstance = nil;

  Ivar ivar = class_getInstanceVariable([host class], "_instance");
  _rctInstance = object_getIvar(host, ivar);

  if (!_rctInstance) {
    return;
  }

  [_rctInstance callFunctionOnBufferedRuntimeExecutor:[=](jsi::Runtime &runtime) {
    auto postMessageFn = [self createPostMessageFunction:runtime];
    auto setOnMessageFn = [self createSetOnMessageFunction:runtime];

    // Use Object.defineProperty with configurable:true so that warm-start
    // re-installations can redefine these globals for the new delegate.
    jsi::Object global = runtime.global();
    jsi::Object objectCtor = global.getPropertyAsObject(runtime, "Object");
    jsi::Function defineProperty = objectCtor.getPropertyAsFunction(runtime, "defineProperty");

    auto defineGlobal = [&](const char *name, jsi::Function &&fn) {
      jsi::Object descriptor(runtime);
      descriptor.setProperty(runtime, "value", std::move(fn));
      descriptor.setProperty(runtime, "writable", false);
      descriptor.setProperty(runtime, "enumerable", false);
      descriptor.setProperty(runtime, "configurable", true);
      defineProperty.call(runtime, global, jsi::String::createFromAscii(runtime, name), descriptor);
    };

    defineGlobal("postMessage", std::move(postMessageFn));
    defineGlobal("setOnMessage", std::move(setOnMessageFn));

    [self setupErrorHandler:runtime];
    // Must run post-bundle (in the buffered executor) because:
    // 1. installConsoleHandler sets __FUSEBOX = true during runtime init
    // 2. didInitializeRuntime: fires BEFORE installConsoleHandler finishes
    // 3. So clearing in didInitializeRuntime: is a no-op — Fusebox re-sets it
    // 4. The buffered executor flushes AFTER bundle eval, guaranteeing the
    //    flag is cleared after Fusebox sets it.
    // For warnings during bundle eval, sandbox JS should call
    // LogBox.ignoreAllLogs() or LogBox.uninstall() to prevent the toast.
    rnsandbox::disableFuseboxLogBoxToast(runtime);
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
          // Convert message to JSON string
          jsi::Object jsonObject = rt.global().getPropertyAsObject(rt, "JSON");
          jsi::Function jsonStringify = jsonObject.getPropertyAsFunction(rt, "stringify");
          jsi::Value jsonResult = jsonStringify.call(rt, messageArg);
          std::string messageJson = jsonResult.getString(rt).utf8(rt);

          // Route message to specific sandbox (same-origin allowed, matches Android)
          BOOL success = [self routeMessage:messageJson toSandbox:targetOrigin];
          if (!success) {
            // Target sandbox doesn't exist
            if (self.eventEmitter && self.hasOnErrorHandler) {
              std::string errorMessage = fmt::format("Target sandbox '{}' not found", targetOrigin);
              SandboxReactNativeViewEventEmitter::OnError errorEvent = {
                  .isFatal = false, .name = "SandboxRoutingError", .message = errorMessage, .stack = ""};
              self.eventEmitter->onError(errorEvent);
            } else {
              std::string errorMessage = fmt::format("Target sandbox '{}' not found", targetOrigin);
              throw jsi::JSError(rt, errorMessage.c_str());
            }
          }
        } else {
          // targetOrigin is undefined/null - route to host
          if (self.eventEmitter && self.hasOnMessageHandler) {
            SandboxReactNativeViewEventEmitter::OnMessage messageEvent = {.data = jsi::dynamicFromValue(rt, args[0])};
            self.eventEmitter->onMessage(messageEvent);
          } else {
            // Event emitter or handler not ready yet (warm start race). Buffer the message.
            jsi::Object jsonObject = rt.global().getPropertyAsObject(rt, "JSON");
            jsi::Function jsonStringify = jsonObject.getPropertyAsFunction(rt, "stringify");
            jsi::Value jsonResult = jsonStringify.call(rt, args[0]);
            std::string messageJson = jsonResult.getString(rt).utf8(rt);
            NSString *nsMsg = [NSString stringWithUTF8String:messageJson.c_str()];
            @synchronized(_pendingHostMessages) {
              [_pendingHostMessages addObject:@{@"data" : nsMsg}];
            }
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
      2, // Accept 1 or 2 arguments: callback and optional delegateId
      [=](jsi::Runtime &rt, const jsi::Value &, const jsi::Value *args, size_t count) {
        if (count < 1 || count > 2) {
          throw jsi::JSError(rt, "Expected 1 or 2 arguments: setOnMessage(callback, delegateId?)");
        }

        const jsi::Value &arg = args[0];
        if (!arg.isObject() || !arg.asObject(rt).isFunction(rt)) {
          throw jsi::JSError(rt, "Expected a function as the first argument");
        }

        jsi::Function fn = arg.asObject(rt).asFunction(rt);

        // Check for optional delegate ID (2nd arg) for per-surface registration
        std::string delegateId;
        if (count == 2 && args[1].isString()) {
          delegateId = args[1].getString(rt).utf8(rt);
        }

        if (!delegateId.empty()) {
          // Per-surface: register under the delegate ID
          _surfaceMessageCallbacks[delegateId] = std::make_shared<jsi::Function>(std::move(fn));
        } else {
          // Legacy: single shared callback (last-writer-wins)
          _onMessageSandbox.reset();
          _onMessageSandbox = std::make_shared<jsi::Function>(std::move(fn));
        }

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

  // On warm start, setGlobalHandler is already stubbed — our error handler
  // from the cold start is still active and broadcasts via the registry,
  // so we can safely skip re-installation.
  jsi::Value setHandlerVal = errorUtils.getProperty(runtime, "setGlobalHandler");
  if (!setHandlerVal.isObject() || !setHandlerVal.asObject(runtime).isFunction(runtime)) {
    return;
  }
  // Check if it's our stub (stub has length 1 and returns undefined for any input).
  // A more reliable check: try to get the handler name. If setGlobalHandler was
  // already called and stubbed, just skip.
  jsi::Function setHandlerFn = setHandlerVal.asObject(runtime).asFunction(runtime);
  // The stub we install has the name "setGlobalHandler" but accepts 1 arg.
  // The real RN setGlobalHandler also accepts 1 arg. We need a different signal.
  // Simplest: use a flag property on ErrorUtils to mark that we've installed.
  jsi::Value installedFlag = errorUtils.getProperty(runtime, "__sandboxErrorHandlerInstalled");
  if (!installedFlag.isUndefined() && installedFlag.getBool()) {
    return;
  }

  std::shared_ptr<jsi::Value> originalHandler = std::make_shared<jsi::Value>(
      errorUtils.getProperty(runtime, "getGlobalHandler").asObject(runtime).asFunction(runtime).call(runtime));

  SandboxReactNativeDelegate *__weak weakSelf = self;

  auto handlerFunc = jsi::Function::createFromHostFunction(
      runtime,
      jsi::PropNameID::forAscii(runtime, "customGlobalErrorHandler"),
      2,
      [weakSelf, capturedOrigin = std::string(_origin), originalHandler = std::move(originalHandler)](
          jsi::Runtime &rt, const jsi::Value &thisVal, const jsi::Value *args, size_t count) -> jsi::Value {
        if (count < 2) {
          return jsi::Value::undefined();
        }

        const jsi::Object &error = args[0].asObject(rt);
        bool isFatal = args[1].getBool();
        std::string name = safeGetStringProperty(rt, error, "name");
        std::string message = safeGetStringProperty(rt, error, "message");
        std::string stack = safeGetStringProperty(rt, error, "stack");

        bool handled = false;

        // When an origin is set, broadcast the error to ALL delegates
        // registered for this origin so every view sharing the VM can
        // independently receive onError events (matches Android behavior).
        if (!capturedOrigin.empty()) {
          auto &registry = rnsandbox::SandboxRegistry::getInstance();
          auto delegates = registry.findAll(capturedOrigin);
          for (auto &delegate : delegates) {
            delegate->postError(name, message, stack, isFatal);
            handled = true;
          }
        }

        if (!handled) {
          SandboxReactNativeDelegate *strongSelf = weakSelf;
          if (strongSelf && strongSelf.eventEmitter && strongSelf.hasOnErrorHandler) {
            SandboxReactNativeViewEventEmitter::OnError errorEvent = {
                .isFatal = isFatal, .name = name, .message = message, .stack = stack};
            strongSelf.eventEmitter->onError(errorEvent);
          } else if (originalHandler->isObject() && originalHandler->asObject(rt).isFunction(rt)) {
            jsi::Function original = originalHandler->asObject(rt).asFunction(rt);
            original.call(rt, args, count);
          }
        }

        return jsi::Value::undefined();
      });

  // Set the new global error handler
  jsi::Function setHandler = errorUtils.getProperty(runtime, "setGlobalHandler").asObject(runtime).asFunction(runtime);
  setHandler.call(runtime, std::move(handlerFunc));

  // Disable further setGlobalHandler from sandbox JS code
  stubJsiFunction(runtime, errorUtils, "setGlobalHandler");

  // Mark that our error handler is installed so warm starts skip re-installation
  errorUtils.setProperty(runtime, "__sandboxErrorHandlerInstalled", true);
}

@end
