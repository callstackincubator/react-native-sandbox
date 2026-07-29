#import "SandboxReactNativeViewComponentView.h"

#import <react/renderer/components/RNSandboxSpec/ComponentDescriptors.h>
#import <react/renderer/components/RNSandboxSpec/EventEmitters.h>
#import <react/renderer/components/RNSandboxSpec/Props.h>
#import <react/renderer/components/RNSandboxSpec/RCTComponentViewHelpers.h>

#import <React-RCTAppDelegate/RCTReactNativeFactory.h>
#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <React/RCTFollyConvert.h>
#import <ReactCommon/RCTHost+Internal.h>
#import <ReactCommon/RCTHost.h>

#import "SandboxReactNativeDelegate.h"

#if RNS_HAS_EXPO_MODULES
#import "SandboxExpoFactory.h"
#endif
#import <objc/runtime.h>

#include "SandboxRegistry.h"

using namespace facebook::react;

#pragma mark - SharedFactory (origin-based pooling)

@interface SharedFactory : NSObject
@property (nonatomic, strong) RCTReactNativeFactory *factory;
@property (nonatomic, assign) NSInteger refCount;
@property (nonatomic, assign) NSInteger idleTTLMs;
@property (nonatomic, assign) NSInteger destroyGeneration;
@end

@implementation SharedFactory
@end

static NSMutableDictionary<NSString *, SharedFactory *> *sSharedFactories = nil;

static void ensureSharedFactories()
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sSharedFactories = [NSMutableDictionary new];
  });
}

static void *kExpoSourceUrlKVOContext = &kExpoSourceUrlKVOContext;

#pragma mark - SandboxReactNativeViewComponentView

@interface SandboxReactNativeViewComponentView () <RCTSandboxReactNativeViewViewProtocol>
@property (nonatomic, strong) RCTReactNativeFactory *reactNativeFactory;
@property (nonatomic, strong, nullable) SandboxReactNativeDelegate *reactNativeDelegate;
@property (nonatomic, assign) BOOL didScheduleLoad;
@property (nonatomic, assign) BOOL usesSharedFactory;
@property (nonatomic, copy, nullable) NSString *currentOrigin;
// Non-nil while we are KVO-observing EXDevLauncherController.sourceUrl (Expo dev-client path).
// Cleared once sourceUrl becomes non-nil and the sandbox load is triggered.
@property (nonatomic, assign) BOOL isObservingExpoSourceUrl;
@end

@implementation SandboxReactNativeViewComponentView {
  SandboxReactNativeViewShadowNode::ConcreteState::Shared _state;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<SandboxReactNativeViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const SandboxReactNativeViewProps>();
    _props = defaultProps;

    self.reactNativeDelegate = [[SandboxReactNativeDelegate alloc] init];
    self.usesSharedFactory = NO;
    self.currentOrigin = nil;
  }

  return self;
}

- (void)updateEventEmitter:(const facebook::react::EventEmitter::Shared &)eventEmitter
{
  [super updateEventEmitter:eventEmitter];
  [self updateEventEmitterIfNeeded];

  // If the factory was destroyed (e.g. by TTL cleanup) but the view is being
  // remounted with the same props (so updateProps won't trigger a reload),
  // detect this here and schedule a reload.
  const auto &props = *std::static_pointer_cast<const SandboxReactNativeViewProps>(_props);
  if (!self.reactNativeFactory && !self.reactNativeRootView && props.componentName.length() > 0 &&
      props.jsBundleSource.length() > 0) {
    [self scheduleReactViewLoad];
  }
}

- (void)updateState:(const facebook::react::State::Shared &)state
           oldState:(const facebook::react::State::Shared &)oldState
{
  [super updateState:state oldState:oldState];
  [self updateEventEmitterIfNeeded];
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<const SandboxReactNativeViewProps>(_props);
  const auto &newViewProps = *std::static_pointer_cast<const SandboxReactNativeViewProps>(props);

  [super updateProps:props oldProps:oldProps];

  if (self.reactNativeDelegate) {
    if (oldViewProps.origin != newViewProps.origin) {
      [self.reactNativeDelegate setOrigin:newViewProps.origin];
    }

    if (oldViewProps.jsBundleSource != newViewProps.jsBundleSource) {
      [self.reactNativeDelegate setJsBundleSource:newViewProps.jsBundleSource];
      RCTHost *host = self.reactNativeFactory.rootViewFactory.reactHost;
      if (host) {
        [host reload];
      }
    }

    if (oldViewProps.allowedTurboModules != newViewProps.allowedTurboModules) {
      std::set<std::string> allowedModules(
          newViewProps.allowedTurboModules.begin(), newViewProps.allowedTurboModules.end());
      [self.reactNativeDelegate setAllowedTurboModules:allowedModules];
    }

    if (oldViewProps.allowedOrigins != newViewProps.allowedOrigins) {
      std::set<std::string> allowedOrigins(newViewProps.allowedOrigins.begin(), newViewProps.allowedOrigins.end());
      [self.reactNativeDelegate setAllowedOrigins:allowedOrigins];
    }

    if (oldViewProps.turboModuleSubstitutions != newViewProps.turboModuleSubstitutions) {
      std::map<std::string, std::string> subs;
      if (newViewProps.turboModuleSubstitutions.isObject()) {
        for (const auto &pair : newViewProps.turboModuleSubstitutions.items()) {
          if (pair.first.isString() && pair.second.isString()) {
            subs[pair.first.getString()] = pair.second.getString();
          }
        }
      }
      [self.reactNativeDelegate setTurboModuleSubstitutions:subs];
    }

    self.reactNativeDelegate.hasOnMessageHandler = newViewProps.hasOnMessageHandler;
    self.reactNativeDelegate.hasOnErrorHandler = newViewProps.hasOnErrorHandler;

    [self updateEventEmitterIfNeeded];
  }

  BOOL turboModuleConfigChanged = oldViewProps.allowedTurboModules != newViewProps.allowedTurboModules ||
      oldViewProps.turboModuleSubstitutions != newViewProps.turboModuleSubstitutions;
  BOOL originChanged = oldViewProps.origin != newViewProps.origin;

  if (turboModuleConfigChanged || originChanged) {
    [self releaseSharedFactory];
    self.reactNativeFactory = nil;
  }

  if (turboModuleConfigChanged || originChanged || oldViewProps.componentName != newViewProps.componentName ||
      oldViewProps.initialProperties != newViewProps.initialProperties ||
      oldViewProps.launchOptions != newViewProps.launchOptions) {
    [self scheduleReactViewLoad];
  }

  if (!self.reactNativeRootView && newViewProps.componentName.length() > 0 &&
      newViewProps.jsBundleSource.length() > 0) {
    [self scheduleReactViewLoad];
  }

  // If the factory was destroyed by TTL cleanup but the view still has a root
  // view (props unchanged, so no reload was triggered above), force a reload.
  // This handles the case where the same sandbox is re-added after TTL expiry.
  if (self.reactNativeRootView && !self.reactNativeFactory && newViewProps.componentName.length() > 0 &&
      newViewProps.jsBundleSource.length() > 0) {
    [self.reactNativeRootView removeFromSuperview];
    self.reactNativeRootView = nil;
    [self scheduleReactViewLoad];
  }
}

- (void)updateEventEmitterIfNeeded
{
  if (self.reactNativeDelegate && _eventEmitter) {
    if (auto eventEmitter = std::static_pointer_cast<const SandboxReactNativeViewEventEmitter>(_eventEmitter)) {
      self.reactNativeDelegate.eventEmitter = eventEmitter;
      // Flush any messages buffered during warm start before the emitter was ready
      [self.reactNativeDelegate flushPendingHostMessages];
    }
  }
}

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
  RCTSandboxReactNativeViewHandleCommand(self, commandName, args);
}

- (void)postMessage:(NSString *)message
{
  std::string messageStr = [message UTF8String];
  [self.reactNativeDelegate postMessage:messageStr];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if (context == kExpoSourceUrlKVOContext && change[NSKeyValueChangeNewKey] != [NSNull null]) {
    [object removeObserver:self forKeyPath:@"sourceUrl" context:kExpoSourceUrlKVOContext];
    self.isObservingExpoSourceUrl = NO;
    self.didScheduleLoad = NO;
    [self scheduleReactViewLoad];
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

- (void)scheduleReactViewLoad
{
  if (self.didScheduleLoad)
    return;
  self.didScheduleLoad = YES;

  dispatch_async(dispatch_get_main_queue(), ^{
    [self loadReactNativeView];
    self.didScheduleLoad = NO;
  });
}

- (void)loadReactNativeView
{
  const auto &props = *std::static_pointer_cast<const SandboxReactNativeViewProps>(_props);

  NSString *moduleName = RCTNSStringFromString(props.componentName);
  NSString *jsBundleSource = RCTNSStringFromString(props.jsBundleSource);

  if (moduleName.length == 0 || jsBundleSource.length == 0 || !self.reactNativeDelegate) {
    return;
  }

  // Ensure the delegate is registered in the SandboxRegistry before loading.
  // The delegate may have been unregistered by TTL cleanup while the view was
  // recycled with the same origin — setOrigin won't be called again in that
  // case since the prop hasn't changed, so we force re-registration here.
  [self.reactNativeDelegate ensureRegistered];

  NSDictionary *initialProperties = @{};
  if (!props.initialProperties.isNull()) {
    initialProperties = (NSDictionary *)convertFollyDynamicToId(props.initialProperties);
  }

  // Inject __sandboxSurfaceId for per-surface message routing (parity with Android)
  NSString *surfaceId = [self.reactNativeDelegate generateSurfaceId];
  NSMutableDictionary *propsWithSurfaceId = [initialProperties mutableCopy];
  propsWithSurfaceId[@"__sandboxSurfaceId"] = surfaceId;
  initialProperties = [propsWithSurfaceId copy];

  NSDictionary *launchOptions = @{};
  if (!props.launchOptions.isNull()) {
    launchOptions = (NSDictionary *)convertFollyDynamicToId(props.launchOptions);
  }

  if (!self.reactNativeFactory) {
    // Guard: verify the bundle URL is resolvable before creating the factory.
    // In Expo dev-client builds EXDevLauncherController.sourceUrl is nil until the
    // host app JS bundle finishes loading (~1-2s after deep-link, set asynchronously on
    // main thread after the network check in EXDevLauncherController completes).
    // If it's nil we register a one-shot KVO observer and retry when it becomes non-nil.
    NSURL *resolvedURL = [self.reactNativeDelegate bundleURL];
    if (!resolvedURL) {
#if DEBUG
      // EXDevLauncherController.sourceUrl is set asynchronously after the deep-link
      // network check completes. If EXDevLauncherController is present at runtime,
      // use KVO on its sourceUrl property to retry the load once it's non-nil.
      // We use objc_getClass() to avoid a hard compile-time dependency on the header.
      if (!self.isObservingExpoSourceUrl) {
        Class devLauncherClass = objc_getClass("EXDevLauncherController");
        if (devLauncherClass) {
          id controller = [devLauncherClass performSelector:@selector(sharedInstance)];
          if (controller) {
            self.isObservingExpoSourceUrl = YES;
            [controller addObserver:self
                         forKeyPath:@"sourceUrl"
                            options:NSKeyValueObservingOptionNew
                            context:kExpoSourceUrlKVOContext];
          }
        }
      }
#endif
      return;
    }
    [self acquireFactory];
  }

  UIView *rnView = [self.reactNativeFactory.rootViewFactory viewWithModuleName:moduleName
                                                             initialProperties:initialProperties
                                                                 launchOptions:launchOptions];

  [self.reactNativeRootView removeFromSuperview];
  self.reactNativeRootView = rnView;
  [self addSubview:rnView];
  rnView.frame = self.bounds;
  rnView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

  [self updateEventEmitterIfNeeded];
}

#pragma mark - Origin-based factory pooling

- (void)acquireFactory
{
  // sSharedFactories is an NSMutableDictionary and is NOT thread-safe.
  // All accesses (acquire, release, and the dispatch_after cleanup block)
  // must occur on the main thread. Fabric component-view updates are
  // dispatched to the main thread by the React renderer, so this invariant
  // holds today — but assert explicitly so any future off-thread call is
  // caught immediately rather than producing a silent data race.
  NSAssert([NSThread isMainThread], @"acquireFactory must be called on the main thread");
  ensureSharedFactories();

  const auto &props = *std::static_pointer_cast<const SandboxReactNativeViewProps>(_props);
  NSString *origin = RCTNSStringFromString(props.origin);

  if (origin.length > 0) {
    SharedFactory *shared = sSharedFactories[origin];
    if (shared) {
      self.reactNativeFactory = shared.factory;
      shared.refCount++;
      shared.idleTTLMs = MAX(shared.idleTTLMs, props.idleTTL);
      self.usesSharedFactory = YES;
      self.currentOrigin = origin;

      // Warm start: the factory's RCTHost already has JSI bindings pointing
      // to the old delegate. Re-install them on the existing runtime so
      // postMessage/setOnMessage route to this new delegate.
      RCTHost *host = shared.factory.rootViewFactory.reactHost;
      if (host) {
        [self.reactNativeDelegate hostDidStart:host];
      }

      return;
    }
  }

#if RNS_HAS_EXPO_MODULES
  self.reactNativeFactory = SandboxCreateExpoFactory(self.reactNativeDelegate);
#else
  self.reactNativeFactory = [[RCTReactNativeFactory alloc] initWithDelegate:self.reactNativeDelegate];
#endif

  if (origin.length > 0) {
    SharedFactory *shared = [SharedFactory new];
    shared.factory = self.reactNativeFactory;
    shared.refCount = 1;
    shared.idleTTLMs = props.idleTTL;
    shared.destroyGeneration = 0;
    sSharedFactories[origin] = shared;
    self.usesSharedFactory = YES;
    self.currentOrigin = origin;
  } else {
    self.usesSharedFactory = NO;
    self.currentOrigin = nil;
  }
}

- (void)releaseSharedFactory
{
  if (!self.usesSharedFactory || !self.currentOrigin) {
    return;
  }
  NSAssert([NSThread isMainThread], @"releaseSharedFactory must be called on the main thread");
  ensureSharedFactories();

  NSString *origin = self.currentOrigin;
  SharedFactory *shared = sSharedFactories[origin];
  if (!shared) {
    self.usesSharedFactory = NO;
    self.currentOrigin = nil;
    return;
  }

  shared.refCount--;
  if (shared.refCount <= 0) {
    NSInteger ttl = shared.idleTTLMs;
    if (ttl > 0) {
      NSInteger gen = ++shared.destroyGeneration;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ttl * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        ensureSharedFactories();
        SharedFactory *current = sSharedFactories[origin];
        if (current && current.refCount <= 0 && current.destroyGeneration == gen) {
          [sSharedFactories removeObjectForKey:origin];
          // Purge all delegates for this origin from the registry so that
          // subsequent pings correctly get SandboxRoutingError.
          // We use unregister (not unregisterDelegate) because the host is
          // being torn down — all delegates for this origin are stale.
          auto &registry = rnsandbox::SandboxRegistry::getInstance();
          registry.unregister([origin UTF8String]);
        }
      });
    } else {
      [sSharedFactories removeObjectForKey:origin];
      auto &registry = rnsandbox::SandboxRegistry::getInstance();
      registry.unregister([origin UTF8String]);
    }
  }

  self.usesSharedFactory = NO;
  self.currentOrigin = nil;
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];

  [self.reactNativeRootView removeFromSuperview];
  self.reactNativeRootView = nil;

  if (self.isObservingExpoSourceUrl) {
    Class devLauncherClass = objc_getClass("EXDevLauncherController");
    if (devLauncherClass) {
      id controller = [devLauncherClass performSelector:@selector(sharedInstance)];
      if (controller) {
        [controller removeObserver:self forKeyPath:@"sourceUrl" context:kExpoSourceUrlKVOContext];
      }
    }
    self.isObservingExpoSourceUrl = NO;
  }

  [self releaseSharedFactory];
  self.reactNativeFactory = nil;
}

- (void)dealloc
{
  if (self.isObservingExpoSourceUrl) {
    Class devLauncherClass = objc_getClass("EXDevLauncherController");
    if (devLauncherClass) {
      id controller = [devLauncherClass performSelector:@selector(sharedInstance)];
      if (controller) {
        [controller removeObserver:self forKeyPath:@"sourceUrl" context:kExpoSourceUrlKVOContext];
      }
    }
    self.isObservingExpoSourceUrl = NO;
  }
  [self releaseSharedFactory];
}

Class<RCTComponentViewProtocol> SandboxReactNativeViewCls(void)
{
  return SandboxReactNativeViewComponentView.class;
}

@end
