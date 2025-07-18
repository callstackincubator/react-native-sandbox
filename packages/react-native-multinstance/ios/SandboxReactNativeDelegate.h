//
//  SandboxReactNativeDelegate.h
//  react-native-multinstance
//
//  Created by Aliaksandr Babrykovich on 25/06/2025.
//

#import <Foundation/Foundation.h>

#import <React-RCTAppDelegate/RCTDefaultReactNativeFactoryDelegate.h>
#import <React/RCTComponent.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A React Native delegate that provides sandboxed environments with filtered module access.
 * This delegate uses RCTFilteredAppDependencyProvider to restrict which native modules
 * are available to the JavaScript runtime, enhancing security in multi-instance scenarios.
 */
@interface SandboxReactNativeDelegate : RCTDefaultReactNativeFactoryDelegate

@property (nonatomic, copy, nullable) RCTDirectEventBlock onMessageHost;
@property (nonatomic, copy, nullable) RCTDirectEventBlock onErrorHost;

/**
 * Sets the list of allowed TurboModules for this sandbox instance.
 * Only modules in this list will be accessible to the JavaScript runtime.
 */
@property (nonatomic, copy) NSArray<NSString *> *allowedTurboModules;

/**
 * Initializes the delegate with a specific JS bundle source.
 * @param jsBundleSource The source for the JavaScript bundle (file path or URL)
 * @return Initialized delegate instance with filtered module access
 */
- (instancetype)initWithJSBundleSource:(NSString *)jsBundleSource;

/**
 * Posts a message to the JavaScript runtime.
 * @param message Dictionary containing the message data
 */
- (void)postMessage:(NSDictionary *)message;

@end

NS_ASSUME_NONNULL_END
