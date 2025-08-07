#import "SandboxReactNativeViewComponentView.h"

#import <react/renderer/components/RNSandboxSpec/ComponentDescriptors.h>
#import <react/renderer/components/RNSandboxSpec/EventEmitters.h>
#import <react/renderer/components/RNSandboxSpec/Props.h>
#import <react/renderer/components/RNSandboxSpec/RCTComponentViewHelpers.h>

#import <React-RCTAppDelegate/RCTReactNativeFactory.h>
#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <React/RCTFollyConvert.h>
#import <ReactCommon/RCTHost.h>

#import "SandboxReactNativeDelegate.h"

using namespace facebook::react;

@interface SandboxReactNativeViewComponentView () <RCTSandboxReactNativeViewViewProtocol>
@property (nonatomic, strong) RCTReactNativeFactory *reactNativeFactory;
@property (nonatomic, strong, nullable) SandboxReactNativeDelegate *reactNativeDelegate;
@property (nonatomic, assign) BOOL didScheduleLoad;
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

    // Create delegate once during initialization
    self.reactNativeDelegate = [[SandboxReactNativeDelegate alloc] init];
  }

  return self;
}

- (void)updateEventEmitter:(const facebook::react::EventEmitter::Shared &)eventEmitter
{
  [super updateEventEmitter:eventEmitter];

  // EventEmitter has been updated, try to set it on the delegate
  [self updateEventEmitterIfNeeded];
}

- (void)updateState:(const facebook::react::State::Shared &)state
           oldState:(const facebook::react::State::Shared &)oldState
{
  [super updateState:state oldState:oldState];

  // State has been updated, eventEmitter might be available now
  [self updateEventEmitterIfNeeded];
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<const SandboxReactNativeViewProps>(_props);
  const auto &newViewProps = *std::static_pointer_cast<const SandboxReactNativeViewProps>(props);

  [super updateProps:props oldProps:oldProps];

  if (self.reactNativeDelegate) {
    if (oldViewProps.id != newViewProps.id) {
      self.reactNativeDelegate.sandboxId = RCTNSStringFromString(newViewProps.id);
    }

    if (oldViewProps.jsBundleSource != newViewProps.jsBundleSource) {
      self.reactNativeDelegate.jsBundleSource = RCTNSStringFromString(newViewProps.jsBundleSource);
    }

    if (oldViewProps.allowedTurboModules != newViewProps.allowedTurboModules) {
      NSArray<NSString *> *allowedTurboModules = @[];
      if (!newViewProps.allowedTurboModules.empty()) {
        NSMutableArray *modules = [NSMutableArray new];
        for (const auto &module : newViewProps.allowedTurboModules) {
          [modules addObject:RCTNSStringFromString(module)];
        }
        allowedTurboModules = [modules copy];
      }
      self.reactNativeDelegate.allowedTurboModules = allowedTurboModules;
    }

    self.reactNativeDelegate.hasOnMessageHandler = newViewProps.hasOnMessageHandler;
    self.reactNativeDelegate.hasOnErrorHandler = newViewProps.hasOnErrorHandler;

    // Always try to set the eventEmitter when props update
    [self updateEventEmitterIfNeeded];
  }

  if (oldViewProps.componentName != newViewProps.componentName ||
      oldViewProps.initialProperties != newViewProps.initialProperties ||
      oldViewProps.launchOptions != newViewProps.launchOptions) {
    [self scheduleReactViewLoad];
  }
}

- (void)updateEventEmitterIfNeeded
{
  if (self.reactNativeDelegate && _eventEmitter) {
    if (auto eventEmitter = std::static_pointer_cast<const SandboxReactNativeViewEventEmitter>(_eventEmitter)) {
      self.reactNativeDelegate.eventEmitter = eventEmitter;
    }
  }
}

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
  RCTSandboxReactNativeViewHandleCommand(self, commandName, args);
}

- (void)postMessage:(NSString *)message
{
  [self.reactNativeDelegate postMessage:message];
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

  // Convert props to Objective-C types
  NSDictionary *initialProperties = @{};
  if (!props.initialProperties.isNull()) {
    initialProperties = (NSDictionary *)convertFollyDynamicToId(props.initialProperties);
  }

  NSDictionary *launchOptions = @{};
  if (!props.launchOptions.isNull()) {
    launchOptions = (NSDictionary *)convertFollyDynamicToId(props.launchOptions);
  }

  // Use existing delegate (properties already updated in updateProps)
  if (!self.reactNativeFactory) {
    self.reactNativeFactory = [[RCTReactNativeFactory alloc] initWithDelegate:self.reactNativeDelegate];
  }
  UIView *rnView = [self.reactNativeFactory.rootViewFactory viewWithModuleName:moduleName
                                                             initialProperties:initialProperties
                                                                 launchOptions:launchOptions];

  [self.reactNativeRootView removeFromSuperview];
  self.reactNativeRootView = rnView;
  [self addSubview:rnView];
  rnView.frame = self.bounds;
  rnView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

  // Try to set eventEmitter after React Native view is loaded
  [self updateEventEmitterIfNeeded];
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];

  [self.reactNativeRootView removeFromSuperview];
  self.reactNativeRootView = nil;

  // Keep the delegate for reuse - it holds configuration and is designed to be persistent
}

Class<RCTComponentViewProtocol> SandboxReactNativeViewCls(void)
{
  return SandboxReactNativeViewComponentView.class;
}

@end
