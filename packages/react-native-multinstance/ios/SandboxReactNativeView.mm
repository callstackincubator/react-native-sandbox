//
//  SandboxReactNativeView.m
//  react-native-multinstance
//
//  Created by Aliaksandr Babrykovich on 28/06/2025.
//

#import "SandboxReactNativeView.h"

#import <React-RCTAppDelegate/RCTReactNativeFactory.h>
#import <ReactCommon/RCTHost.h>

#import "SandboxReactNativeDelegate.h"

@interface SandboxReactNativeView ()

@property (nonatomic, assign) BOOL didScheduleLoad;
@property (nonatomic, strong) RCTReactNativeFactory *reactNativeFactory;
@property (nonatomic, strong) SandboxReactNativeDelegate *reactNativeDelegate;
@property (nonatomic, strong) UIView *rootView;

@end

@implementation SandboxReactNativeView

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _moduleName = @"App";
    _jsBundleSource = @"sandbox";
    _allowedTurboModules = @[@"NativeMicrotasksCxx"];
    _initialProperties = @{};
    _launchOptions = @{};
    _onMessage = nil;
    _onError = nil;
  }
  return self;
}

- (void)setModuleName:(NSString *)moduleName {
  if (![_moduleName isEqualToString:moduleName]) {
    _moduleName = [moduleName copy];
    [self scheduleReactViewLoad];
  }
}

- (void)setJsBundleSource:(NSString *)jsBundleSource {
  if (![_jsBundleSource isEqualToString:jsBundleSource]) {
    _jsBundleSource = [jsBundleSource copy];
    [self scheduleReactViewLoad];
  }
}

- (void)setInitialProperties:(NSDictionary *)initialProperties {
  if (![_initialProperties isEqualToDictionary:initialProperties]) {
    _initialProperties = [initialProperties copy];
    [self scheduleReactViewLoad];
  }
}

- (void)setLaunchOptions:(NSDictionary *)launchOptions {
  if (![_launchOptions isEqualToDictionary:launchOptions]) {
    _launchOptions = [launchOptions copy];
    [self scheduleReactViewLoad];
  }
}

- (void)setOnMessage:(RCTDirectEventBlock)onMessage {
  if (onMessage != _onMessage) {
    _onMessage = [onMessage copy];
    _reactNativeDelegate.onMessageHost = _onMessage;
  }
}

- (void)setOnError:(RCTDirectEventBlock)onError {
  if (onError != _onError) {
    _onError = [onError copy];
    _reactNativeDelegate.onErrorHost = _onError;
  }
}

- (void)setAllowedTurboModules:(NSArray<NSString *> *)allowedTurboModules {
  if (![allowedTurboModules isEqual:_allowedTurboModules]) {
    _allowedTurboModules = [allowedTurboModules copy];
    [self scheduleReactViewLoad];
  }
}

- (void)postMessage:(NSDictionary *)message {
  [_reactNativeDelegate postMessage:message];
}

- (void)scheduleReactViewLoad {
  if (_didScheduleLoad) return;
  _didScheduleLoad = YES;

  dispatch_async(dispatch_get_main_queue(), ^{
    [self loadReactNativeView];
    self.didScheduleLoad = NO;
  });
}

- (void)loadReactNativeView {
  if (_moduleName.length == 0 || _jsBundleSource.length == 0 || _allowedTurboModules == nil) {
    return;
  }

  SandboxReactNativeDelegate *delegate = [[SandboxReactNativeDelegate alloc] initWithJSBundleSource:_jsBundleSource];
  delegate.onMessageHost = _onMessage;
  delegate.onErrorHost = _onError;
  delegate.allowedTurboModules = _allowedTurboModules;

  RCTReactNativeFactory *factory = [[RCTReactNativeFactory alloc] initWithDelegate:delegate];

  UIView *rnView = [factory.rootViewFactory viewWithModuleName:_moduleName
                                            initialProperties:_initialProperties
                                                 launchOptions:_launchOptions];

  [_rootView removeFromSuperview];
  _rootView = rnView;
  [self addSubview:rnView];
  rnView.frame = self.bounds;
  rnView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

  _reactNativeDelegate = delegate;
  _reactNativeFactory = factory;
}

@end
