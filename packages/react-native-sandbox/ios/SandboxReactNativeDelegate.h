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
 * Checks if the delegate is properly configured for bidirectional communication
 * @return YES if both sandbox→host and host→sandbox communication should work
 */
- (BOOL)isCommunicationReady;

#pragma mark - Static Registry Methods

/**
 * Registers a sandbox delegate with the global registry
 * @param sandboxId Unique identifier for the sandbox
 * @param delegate The delegate instance to register
 */
+ (void)registerSandbox:(NSString *)sandboxId delegate:(SandboxReactNativeDelegate *)delegate;

/**
 * Unregisters a sandbox delegate from the global registry
 * @param sandboxId The sandbox identifier to unregister
 */
+ (void)unregisterSandbox:(NSString *)sandboxId;

/**
 * Retrieves a sandbox delegate by ID
 * @param sandboxId The sandbox identifier to look up
 * @return The delegate instance or nil if not found
 */
+ (nullable SandboxReactNativeDelegate *)getSandbox:(NSString *)sandboxId;

/**
 * Routes a message to a specific sandbox
 * @param message The message to send
 * @param targetId The target sandbox identifier
 * @return YES if message was routed successfully, NO if target not found
 */
+ (BOOL)routeMessage:(NSString *)message toSandbox:(NSString *)targetId;

@end

NS_ASSUME_NONNULL_END
