//
//  SandboxReactNativeView.h
//  MultiInstancePOC
//
//  Created by Aliaksandr Babrykovich on 28/06/2025.
//

#import <React/RCTView.h>

NS_ASSUME_NONNULL_BEGIN

@interface SandboxReactNativeView : RCTView

@property (nonatomic, copy) NSString *contextId;
@property (nonatomic, copy) NSString *moduleName;
@property (nonatomic, copy) NSString *jsBundleName;
@property (nonatomic, copy) NSDictionary *initialProperties;
@property (nonatomic, copy) NSDictionary *launchOptions;
@property (nonatomic, copy, nullable) RCTDirectEventBlock onError;

@end

NS_ASSUME_NONNULL_END

