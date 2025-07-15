//
//  SandboxReactNativeViewManager.h
//  MultiInstancePOC
//
//  Created by Aliaksandr Babrykovich on 22/06/2025.
//

#import <React/RCTViewManager.h>
#import <React/RCTBridge.h>

#import "SandboxReactNativeView.h"

@interface RCT_EXTERN_MODULE(SandboxReactNativeViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(moduleName, NSString)
RCT_EXPORT_VIEW_PROPERTY(jsBundleSource, NSString)
RCT_EXPORT_VIEW_PROPERTY(initialProperties, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(launchOptions, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(allowedTurboModules, NSArray<NSString *>)
RCT_EXPORT_VIEW_PROPERTY(onError, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onMessage, RCTDirectEventBlock)

RCT_EXTERN_METHOD(postMessage:(nonnull NSNumber *)reactTag message:(NSDictionary *)message)

@end
