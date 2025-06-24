//
//  SandboxReactNativeView.swift
//  MultiInstancePOC
//
//  Created by Aliaksandr Babrykovich on 17/06/2025.
//

import Foundation
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

@objc(SandboxReactNativeView)
class SandboxReactNativeView: RCTView {
  @objc var contextId: NSString = "${contextId}" as NSString
  @objc var onError: RCTDirectEventBlock?

  @objc var moduleName: NSString = "sandbox" as NSString {
    didSet {
      guard oldValue != moduleName else { return }
      scheduleReactViewLoad()
    }
  }

  @objc var jsBundleName: NSString = "index" {
    didSet {
      guard oldValue != jsBundleName else { return }
      scheduleReactViewLoad()
    }
  }

  @objc var initialProperties: [String: Any] = [:] {
    didSet {
      guard !NSDictionary(dictionary: oldValue).isEqual(to: initialProperties) else { return }
      loadReactNativeView()
    }
  }

  @objc var launchOptions: [String: Any] = [:] {
    didSet {
      guard !NSDictionary(dictionary: oldValue).isEqual(to: launchOptions) else { return }
      loadReactNativeView()
    }
  }

  private var didScheduleLoad = false

  private var reactNativeDelegate: RCTDefaultReactNativeFactoryDelegate?
  private var reactNativeFactory: RCTReactNativeFactory?
  private var rootView: UIView?

  private func scheduleReactViewLoad() {
    guard !didScheduleLoad else { return }
    didScheduleLoad = true

    // Schedule loading on next run loop iteration (all props likely set)
    DispatchQueue.main.async { [weak self] in
      self?.loadReactNativeView()
      self?.didScheduleLoad = false
    }
  }

  private func loadReactNativeView() {
    guard !moduleName.isEqual(to: "") && !jsBundleName.isEqual(to: "") && !contextId.isEqual(to: "") else { return }

    let delegate = SandboxReactNativeDelegate(jsBundleName: jsBundleName as String)
    let factory = RCTReactNativeFactory(delegate: delegate)
    factory.delegate = delegate

    let rnView = factory.rootViewFactory.view(
      withModuleName: moduleName as String,
      initialProperties: initialProperties.merging([
        "contextId": contextId
      ]) { _, new in new },
      launchOptions: launchOptions
    )

    rootView?.removeFromSuperview()
    rootView = rnView
    addSubview(rnView)
    rnView.frame = bounds
    rnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    reactNativeDelegate = delegate
    reactNativeFactory = factory
  }
}
