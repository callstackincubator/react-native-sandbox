// Copyright 2025-present Callstack. All rights reserved.

#import "SandboxExpoFactory.h"

// EXReactNativeFactory is the ObjC class name — import its ObjC header directly.
#import <Expo/ExpoReactNativeFactory.h>

RCTReactNativeFactory *SandboxCreateExpoFactory(id<RCTReactNativeFactoryDelegate> delegate)
{
  return [[EXReactNativeFactory alloc] initWithDelegate:delegate];
}
