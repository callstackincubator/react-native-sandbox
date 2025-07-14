import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  var reactNativeDelegate: ReactNativeDelegate!
  var reactNativeFactory: RCTReactNativeFactory!

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    reactNativeDelegate = ReactNativeDelegate(jsBundleName: "index")
    reactNativeFactory = RCTReactNativeFactory(delegate: reactNativeDelegate)
    reactNativeDelegate.dependencyProvider = RCTAppDependencyProvider()

    let viewController = UIViewController()
    viewController.view = reactNativeFactory.rootViewFactory.view(
      withModuleName: "ExampleHostApp",
      initialProperties: [:],
      launchOptions: launchOptions
    )

    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = viewController
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
