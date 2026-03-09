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

#include <map>
#include <string>
#include <vector>

NS_ASSUME_NONNULL_BEGIN

/**
 * A React Native delegate that provides sandboxed environments with filtered module access.
 * This delegate uses RCTFilteredAppDependencyProvider to restrict which native modules
 * are available to the JavaScript runtime, enhancing security in multi-instance scenarios.
 *
 * This class provides the core React Native integration functionality.
 * For C++ registry integration, use SandboxDelegateWrapper.
 */
@interface SandboxReactNativeDelegate : RCTDefaultReactNativeFactoryDelegate

@property (nonatomic) std::shared_ptr<const facebook::react::SandboxReactNativeViewEventEmitter> eventEmitter;
@property (nonatomic, assign) BOOL hasOnMessageHandler;
@property (nonatomic, assign) BOOL hasOnErrorHandler;
@property (nonatomic, readwrite) std::string origin;
@property (nonatomic, readwrite) std::string jsBundleSource;

/**
 * Sets the list of allowed TurboModules for this sandbox instance.
 * Only modules in this list will be accessible to the JavaScript runtime.
 */
@property (nonatomic, readwrite) std::set<std::string> allowedTurboModules;

/**
 * Sets the list of allowed origins for this sandbox instance.
 * Only sandboxes with origins in this list can send messages to this sandbox.
 */
@property (nonatomic, readwrite) std::set<std::string> allowedOrigins;

/**
 * Sets the TurboModule substitution map for this sandbox instance.
 * Keys are module names that sandbox JS code requests, values are the actual
 * native module names to resolve instead. Substituted modules are implicitly allowed.
 *
 * Example: {"RNCAsyncStorage": "SandboxedAsyncStorage"} means when sandbox JS
 * requests RNCAsyncStorage, the delegate resolves SandboxedAsyncStorage instead
 * and configures it with the sandbox context (origin, etc.) if it implements
 * ISandboxAwareModule.
 */
@property (nonatomic, readwrite) std::map<std::string, std::string> turboModuleSubstitutions;

/**
 * Initializes the delegate.
 * @return Initialized delegate instance with filtered module access
 */
- (instancetype)init;

/**
 * Posts a message to the JavaScript runtime.
 * @param message C++ string containing the JSON.stringified message
 */
- (void)postMessage:(const std::string &)message;

/**
 * Routes a message to a specific sandbox delegate.
 * @param message The message to route
 * @param targetId The ID of the target sandbox
 * @return true if the message was successfully routed, false otherwise
 */
- (bool)routeMessage:(const std::string &)message toSandbox:(const std::string &)targetId;

@end

NS_ASSUME_NONNULL_END
