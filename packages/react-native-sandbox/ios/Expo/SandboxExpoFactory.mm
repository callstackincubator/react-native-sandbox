// Copyright 2025-present Callstack. All rights reserved.

#import "SandboxExpoFactory.h"

// ExpoReactNativeFactory is a Swift class in the Expo pod. Its ObjC interface is
// generated during build and available via the Swift compatibility header.
#if __has_include(<Expo/Expo-Swift.h>)
#import <Expo/Expo-Swift.h>
#elif __has_include(<Expo/Swift.h>)
#import <Expo/Swift.h>
#else
#import "Expo-Swift.h"
#endif

RCTReactNativeFactory *SandboxCreateExpoFactory(id<RCTReactNativeFactoryDelegate> delegate)
{
  return [[ExpoReactNativeFactory alloc] initWithDelegate:delegate];
}
