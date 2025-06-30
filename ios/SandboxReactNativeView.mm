//
//  SandboxReactNativeView.m
//  MultiInstancePOC
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
@property (nonatomic, strong) RCTDefaultReactNativeFactoryDelegate *reactNativeDelegate;
@property (nonatomic, strong) UIView *rootView;

@end

@implementation SandboxReactNativeView

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _contextId = @"${contextId}";
    _moduleName = @"sandbox";
    _jsBundleName = @"index";
    _initialProperties = @{};
    _launchOptions = @{};
  }
  return self;
}

- (void)setModuleName:(NSString *)moduleName {
  if (![_moduleName isEqualToString:moduleName]) {
    _moduleName = [moduleName copy];
    [self scheduleReactViewLoad];
  }
}

- (void)setJsBundleName:(NSString *)jsBundleName {
  if (![_jsBundleName isEqualToString:jsBundleName]) {
    _jsBundleName = [jsBundleName copy];
    [self scheduleReactViewLoad];
  }
}

- (void)setInitialProperties:(NSDictionary *)initialProperties {
  if (![_initialProperties isEqualToDictionary:initialProperties]) {
    _initialProperties = [initialProperties copy];
    [self loadReactNativeView];
  }
}

- (void)setLaunchOptions:(NSDictionary *)launchOptions {
  if (![_launchOptions isEqualToDictionary:launchOptions]) {
    _launchOptions = [launchOptions copy];
    [self loadReactNativeView];
  }
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
  if (_moduleName.length == 0 || _jsBundleName.length == 0 || _contextId.length == 0) {
    return;
  }

  SandboxReactNativeDelegate *delegate = [[SandboxReactNativeDelegate alloc] initWithJSBundleName:_jsBundleName];

  RCTReactNativeFactory *factory = [[RCTReactNativeFactory alloc] initWithDelegate:delegate];
  factory.delegate = delegate;
  factory.rootViewFactory.reactHost = [factory.rootViewFactory createReactHost:_launchOptions];
  factory.rootViewFactory.reactHost.runtimeDelegate = (id<RCTHostRuntimeDelegate>)delegate;

  NSMutableDictionary *mergedProps = [_initialProperties mutableCopy];
  mergedProps[@"contextId"] = _contextId;

  UIView *rnView = [factory.rootViewFactory viewWithModuleName:_moduleName
                                            initialProperties:mergedProps
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
