//
//  SandboxReactNativeDelegate.h
//  react-native-sandbox
//
//  Created by Aliaksandr Babrykovich on 25/06/2025.
//

#import <Foundation/Foundation.h>

#import <React-RCTAppDelegate/RCTDefaultReactNativeFactoryDelegate.h>
#import <React/RCTComponent.h>
#import <react/renderer/components/RNSandboxSpec/EventEmitters.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A React Native delegate that provides sandboxed environments with filtered module access.
 * This delegate uses RCTFilteredAppDependencyProvider to restrict which native modules
 * are available to the JavaScript runtime, enhancing security in multi-instance scenarios.
 *
 * Registry functionality has been moved to SandboxRegistry class to maintain single responsibility.
 */
@interface SandboxReactNativeDelegate : RCTDefaultReactNativeFactoryDelegate

@property (nonatomic) std::shared_ptr<const facebook::react::SandboxReactNativeViewEventEmitter> eventEmitter;
@property (nonatomic, assign) BOOL hasOnMessageHandler;
@property (nonatomic, assign) BOOL hasOnErrorHandler;
@property (nonatomic, copy, nullable) NSString *sandboxId;
@property (nonatomic, copy, nullable) NSString *jsBundleSource;

/**
 * Sets the list of allowed TurboModules for this sandbox instance.
 * Only modules in this list will be accessible to the JavaScript runtime.
 */
@property (nonatomic, copy) NSArray<NSString *> *allowedTurboModules;

/**
 * Initializes the delegate.
 * @return Initialized delegate instance with filtered module access
 */
- (instancetype)init;

/**
 * Posts a message to the JavaScript runtime.
 * @param message String containing the JSON.stringified message
 */
- (void)postMessage:(NSString *)message;

/**
 * Routes a message to a specific sandbox delegate.
 * @param message The message to route
 * @param targetId The ID of the target sandbox
 * @return YES if the message was successfully routed, NO otherwise
 */
- (BOOL)routeMessage:(NSString *)message toSandbox:(NSString *)targetId;

@end

NS_ASSUME_NONNULL_END
