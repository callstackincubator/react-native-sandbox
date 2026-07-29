// Copyright 2025-present Callstack. All rights reserved.
//
// Thin helper so Core ObjC++ files can create an ExpoReactNativeFactory without
// directly importing the Expo Swift-generated header (which is only available
// when expo-modules-core is present and RNS_HAS_EXPO_MODULES=1).

#import <React-RCTAppDelegate/RCTReactNativeFactory.h>

@protocol RCTReactNativeFactoryDelegate;

NS_ASSUME_NONNULL_BEGIN

/// Returns a new ExpoReactNativeFactory configured with the given delegate.
/// Core files use this function behind a #if RNS_HAS_EXPO_MODULES guard so the
/// Expo pod dependency is only pulled in when expo-modules-core is present.
RCTReactNativeFactory *SandboxCreateExpoFactory(id<RCTReactNativeFactoryDelegate> delegate);

NS_ASSUME_NONNULL_END
