#pragma once

#import <UIKit/UIKit.h>
#import <React/RCTViewComponentView.h>

NS_ASSUME_NONNULL_BEGIN

@class SandboxReactNativeDelegate;

/*
 * UIView class for the SandboxReactNativeView component.
 */
@interface SandboxReactNativeViewComponentView : RCTViewComponentView

@property (nonatomic, strong, nullable) UIView *reactNativeRootView;

@end

NS_ASSUME_NONNULL_END 