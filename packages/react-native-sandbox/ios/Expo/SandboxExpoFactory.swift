// Copyright 2025-present Callstack. All rights reserved.

import Expo
import React

// ObjC++ in the same pod cannot reference ExpoReactNativeFactory directly because its
// generated Expo-Swift.h lives in DerivedData, not in Pods/Headers/Public/Expo.
// This helper exposes a single factory method that ObjC++ can call via React_Sandbox-Swift.h.
@objc(SandboxExpoFactory)
public class SandboxExpoFactory: NSObject {
  @objc public static func create(withDelegate delegate: RCTReactNativeFactoryDelegate) -> RCTReactNativeFactory {
    return ExpoReactNativeFactory(delegate: delegate)
  }
}
