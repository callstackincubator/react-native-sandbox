import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  var reactNativeDelegate: ReactNativeDelegate?
  var reactNativeFactory1: RCTReactNativeFactory?
  var reactNativeFactory2: RCTReactNativeFactory?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let delegate = ReactNativeDelegate()
    let factory1 = RCTReactNativeFactory(delegate: delegate)
    let factory2 = RCTReactNativeFactory(delegate: delegate)
    
    delegate.dependencyProvider = RCTAppDependencyProvider()

    reactNativeDelegate = delegate
    reactNativeFactory1 = factory1
    reactNativeFactory2 = factory2

    window = UIWindow(frame: UIScreen.main.bounds)
    let splitViewController = SplitViewController()

    let rnView1 = factory1.rootViewFactory.view(
      withModuleName: "A",
      initialProperties: ["sourceName": "A", "targetName": "B"],
      launchOptions: launchOptions
    )
    
    let rnView2 = factory2.rootViewFactory.view(
      withModuleName: "B",
      initialProperties: ["sourceName": "B", "targetName": "A"],
      launchOptions: launchOptions
    )
    
    splitViewController.setViews(topView: rnView1, bottomView: rnView2)
    window?.rootViewController = splitViewController
    window?.makeKeyAndVisible()

    return true
  }
}

class ReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
  override func sourceURL(for bridge: RCTBridge) -> URL? {
    self.bundleURL()
  }

  override func bundleURL() -> URL? {
#if DEBUG
    RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
#else
    Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }
}
