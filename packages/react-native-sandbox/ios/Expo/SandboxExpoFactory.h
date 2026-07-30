// Copyright 2025-present Callstack. All rights reserved.

#import <Expo/ExpoReactNativeFactory.h>

NS_ASSUME_NONNULL_BEGIN

/// EXReactNativeFactory subclass that creates a per-origin scoped AppContext.
/// Overrides host:didInitializeRuntime: to replace the default (unscoped)
/// EXAppContext with one whose document/cache directories are namespaced to
/// the sandbox origin — identical to what Expo Go does per-experience.
@interface SandboxExpoFactory : EXReactNativeFactory

- (instancetype)initWithDelegate:(id<RCTReactNativeFactoryDelegate>)delegate
                          origin:(nullable NSString *)origin;

@end

NS_ASSUME_NONNULL_END
