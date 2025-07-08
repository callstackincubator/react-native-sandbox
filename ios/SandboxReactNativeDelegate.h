//
//  SandboxReactNativeDelegate.h
//  MultiInstancePOC
//
//  Created by Aliaksandr Babrykovich on 25/06/2025.
//

#import <Foundation/Foundation.h>

#import <React-RCTAppDelegate/RCTDefaultReactNativeFactoryDelegate.h>
#import <React/RCTComponent.h>

NS_ASSUME_NONNULL_BEGIN

@interface SandboxReactNativeDelegate : RCTDefaultReactNativeFactoryDelegate

@property (nonatomic, copy, nullable) RCTDirectEventBlock onMessageHost;
@property (nonatomic, copy, nullable) RCTDirectEventBlock onErrorHost;

- (instancetype)initWithJSBundleName:(NSString *)jsBundleName;
- (void)postMessage:(NSDictionary *)message;

@end

NS_ASSUME_NONNULL_END
