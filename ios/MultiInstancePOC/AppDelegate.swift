import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  var reactNativeDelegate1: ReactNativeDelegate?
  var reactNativeDelegate2: ReactNativeDelegate?
  var reactNativeFactory1: RCTReactNativeFactory?
  var reactNativeFactory2: RCTReactNativeFactory?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let delegate1 = ReactNativeDelegate(jsBundleName: "index.A")
    let delegate2 = ReactNativeDelegate(jsBundleName: "index.B")
    let factory1 = RCTReactNativeFactory(delegate: delegate1)
    let factory2 = RCTReactNativeFactory(delegate: delegate2)

    reactNativeDelegate1 = delegate1
    reactNativeDelegate2 = delegate2
    delegate1.dependencyProvider = RCTAppDependencyProvider()
    delegate2.dependencyProvider = RCTAppDependencyProvider()

    reactNativeFactory1 = factory1
    reactNativeFactory2 = factory2

    window = UIWindow(frame: UIScreen.main.bounds)
    let splitViewController = SplitViewController()

    let rnView1 = factory1.rootViewFactory.view(
      withModuleName: "A",
      initialProperties: [
        "sourceName": "A",
        "targetName": "B",
        "backgroundColor": "#CCFFCC"
      ],
      launchOptions: launchOptions
    )

    let rnView2 = factory2.rootViewFactory.view(
      withModuleName: "B",
      initialProperties: [
        "sourceName": "B",
        "targetName": "A",
        "backgroundColor": "#CCCCFF"
      ],
      launchOptions: launchOptions
    )

    splitViewController.setViews(topView: rnView1, bottomView: rnView2)
    window?.rootViewController = splitViewController
    window?.makeKeyAndVisible()

    return true
  }
}

class ReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
  let jsBundleName: String
  
  init(jsBundleName: String) {
    self.jsBundleName = jsBundleName
  }

  override func sourceURL(for bridge: RCTBridge) -> URL? {
    self.bundleURL()
  }

  override func bundleURL() -> URL? {
#if DEBUG
    RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: jsBundleName)
#else
    Bundle.main.url(forResource: jsBundleName, withExtension: "jsbundle")
#endif
  }
}
