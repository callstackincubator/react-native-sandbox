//
//  SandboxReactNativeViewManager.h
//  MultiInstancePOC
//
//  Created by Aliaksandr Babrykovich on 22/06/2025.
//

#import <React/RCTViewManager.h>

@interface RCT_EXTERN_MODULE(SandboxReactNativeViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(contextId, NSString)
RCT_EXPORT_VIEW_PROPERTY(jsBundleName, NSString)
RCT_EXPORT_VIEW_PROPERTY(moduleName, NSString)
RCT_EXPORT_VIEW_PROPERTY(initialProperties, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(launchOptions, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(onError, RCTDirectEventBlock)

@end
