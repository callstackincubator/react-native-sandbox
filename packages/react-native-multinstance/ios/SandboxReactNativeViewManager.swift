//
//  SandboxReactNativeViewManager.swift
//  MultiInstancePOC
//
//  Created by Aliaksandr Babrykovich on 18/06/2025.
//

import Foundation
import React

@objc(SandboxReactNativeViewManager)
class SandboxReactNativeViewManager: RCTViewManager {
  override static func requiresMainQueueSetup() -> Bool {
    return true
  }

  override func view() -> UIView! {
    return SandboxReactNativeView()
  }

  @objc(postMessage:message:)
  func postMessage(_ reactTag: NSNumber, message: NSDictionary) {
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }

      let view = self.bridge.uiManager.view(forReactTag: reactTag)

      guard let sandboxView = view as? SandboxReactNativeView else {
        return
      }

      sandboxView.postMessage(message as! [AnyHashable : Any])
    }
  }
}
