//
//  SandboxReactNativeDelegate.h
//  MultiInstancePOC
//
//  Created by Aliaksandr Babrykovich on 25/06/2025.
//

#import <Foundation/Foundation.h>

#import <React-RCTAppDelegate/RCTDefaultReactNativeFactoryDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface SandboxReactNativeDelegate : RCTDefaultReactNativeFactoryDelegate

- (instancetype)initWithJSBundleName:(NSString *)jsBundleName;

@end

NS_ASSUME_NONNULL_END
