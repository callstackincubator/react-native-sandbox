#import "SandboxReactNativeViewComponentView.h"

#import <react/renderer/components/RNMultInstanceSpec/ComponentDescriptors.h>
#import <react/renderer/components/RNMultInstanceSpec/EventEmitters.h>
#import <react/renderer/components/RNMultInstanceSpec/Props.h>
#import <react/renderer/components/RNMultInstanceSpec/RCTComponentViewHelpers.h>

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <React-RCTAppDelegate/RCTReactNativeFactory.h>
#import <ReactCommon/RCTHost.h>
#import <React/RCTFollyConvert.h>

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
  }

  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<SandboxReactNativeViewProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<SandboxReactNativeViewProps const>(props);

  bool shouldReload = false;

  if (oldViewProps.moduleName != newViewProps.moduleName ||
      oldViewProps.jsBundleSource != newViewProps.jsBundleSource ||
      oldViewProps.initialProperties != newViewProps.initialProperties ||
      oldViewProps.launchOptions != newViewProps.launchOptions ||
      oldViewProps.allowedTurboModules != newViewProps.allowedTurboModules) {
    shouldReload = true;
  }

  [super updateProps:props oldProps:oldProps];

  if (self.reactNativeDelegate) {
    self.reactNativeDelegate.hasOnMessageHandler = newViewProps.hasOnMessageHandler;
    self.reactNativeDelegate.hasOnErrorHandler = newViewProps.hasOnErrorHandler;
  }

  if (shouldReload) {
    [self scheduleReactViewLoad];
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
  if (self.didScheduleLoad) return;
  self.didScheduleLoad = YES;

  dispatch_async(dispatch_get_main_queue(), ^{
    [self loadReactNativeView];
    self.didScheduleLoad = NO;
  });
}

- (void)loadReactNativeView
{
  const auto &props = *std::static_pointer_cast<SandboxReactNativeViewProps const>(_props);

  NSString *moduleName = RCTNSStringFromString(props.moduleName);
  NSString *jsBundleSource = RCTNSStringFromString(props.jsBundleSource);

  if (moduleName.length == 0 || jsBundleSource.length == 0) {
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
  
  NSArray<NSString *> *allowedTurboModules = @[];
  if (!props.allowedTurboModules.empty()) {
    NSMutableArray *modules = [NSMutableArray new];
    for (const auto &module : props.allowedTurboModules) {
      [modules addObject:RCTNSStringFromString(module)];
    }
    allowedTurboModules = [modules copy];
  }

  SandboxReactNativeDelegate *delegate = [[SandboxReactNativeDelegate alloc] initWithJSBundleSource:jsBundleSource];
  delegate.allowedTurboModules = allowedTurboModules;
  
  if (auto eventEmitter = std::static_pointer_cast<SandboxReactNativeViewEventEmitter const>(_eventEmitter)) {
    delegate.eventEmitter = eventEmitter;
  }

  delegate.hasOnMessageHandler = props.hasOnMessageHandler;
  delegate.hasOnErrorHandler = props.hasOnErrorHandler;

  RCTReactNativeFactory *factory = [[RCTReactNativeFactory alloc] initWithDelegate:delegate];
  UIView *rnView = [factory.rootViewFactory viewWithModuleName:moduleName
                                            initialProperties:initialProperties
                                                 launchOptions:launchOptions];

  [self.reactNativeRootView removeFromSuperview];
  self.reactNativeRootView = rnView;
  [self addSubview:rnView];
  rnView.frame = self.bounds;
  rnView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

  self.reactNativeDelegate = delegate;
  self.reactNativeFactory = factory;
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  [self.reactNativeRootView removeFromSuperview];
  self.reactNativeRootView = nil;
  self.reactNativeDelegate = nil;
  self.reactNativeFactory = nil;
}

Class<RCTComponentViewProtocol> SandboxReactNativeViewCls(void)
{
  return SandboxReactNativeViewComponentView.class;
}

@end 
