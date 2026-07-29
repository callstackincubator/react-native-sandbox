// Copyright 2025-present Callstack. All rights reserved.

import ExpoModulesCore
import Foundation

/// Bridges Swift-only Expo APIs to ObjC so the sandbox can create a scoped
/// EXAppContext per origin without exposing Swift value types across the boundary.
@objc(SandboxAppContextBridge)
public class SandboxAppContextBridge: NSObject {
  /// Returns an EXAppContext whose document and cache directories are namespaced
  /// to the given sandbox origin. Callers own the returned object.
  @objc public static func createScopedAppContext(forOrigin origin: String) -> EXAppContext {
    let sanitized =
      origin
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: "@", with: "-")
      .replacingOccurrences(of: ":", with: "-")

    let fileManager = FileManager.default
    let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first

    let docDir = docs?.appendingPathComponent("SandboxData/\(sanitized)")
    let cacheDir = caches?.appendingPathComponent("SandboxData/\(sanitized)")

    let config = AppContextConfig(
      documentDirectory: docDir,
      cacheDirectory: cacheDir,
      appGroups: nil
    )
    return AppContext(config: config)
  }
}
