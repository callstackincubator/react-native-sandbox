//
//  SandboxRegistry.h
//  react-native-sandbox
//
//  Created by Aliaksandr Babrykovich on 25/06/2025.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A singleton registry for managing sandbox delegates across multiple instances.
 * This class provides thread-safe registration, unregistration, and retrieval of delegates
 * for inter-sandbox communication.
 *
 * The registry is type-agnostic and works with any delegate type that supports
 * the required communication protocol.
 */
@interface SandboxRegistry : NSObject

/**
 * Returns the shared singleton instance of the registry.
 * @return The shared registry instance
 */
+ (instancetype)shared;

/**
 * Registers a delegate with the specified origin and allowed origins.
 * @param sandboxOrigin Unique identifier for the sandbox
 * @param delegate The delegate instance to register (any type)
 * @param allowedOrigins Array of sandbox origins that are allowed to send messages to this sandbox.
 *                      If nil or empty, no other sandboxes will be allowed to send messages (except 'host').
 *                      Re-registering with new allowedOrigins will override previous settings.
 */
- (void)registerSandbox:(NSString *)sandboxOrigin
               delegate:(id)delegate
         allowedOrigins:(nullable NSArray<NSString *> *)allowedOrigins;

/**
 * Unregisters a delegate by origin.
 * @param sandboxOrigin The origin of the sandbox to unregister
 */
- (void)unregister:(NSString *)sandboxOrigin;

/**
 * Finds a delegate by origin.
 * @param sandboxOrigin The origin of the sandbox to find
 * @return The registered delegate, or nil if not found
 */
- (nullable id)find:(NSString *)sandboxOrigin;

/**
 * Checks if communication is permitted from one sandbox to another.
 * @param sourceOrigin The origin of the sandbox attempting to send a message
 * @param targetOrigin The origin of the sandbox that would receive the message
 * @return YES if the source sandbox is permitted to send messages to the target, NO otherwise
 */
- (BOOL)isPermittedFrom:(NSString *)sourceOrigin to:(NSString *)targetOrigin;

@end

NS_ASSUME_NONNULL_END