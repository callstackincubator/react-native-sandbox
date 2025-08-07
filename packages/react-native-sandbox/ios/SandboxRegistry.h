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
 * Registers a delegate with the specified ID.
 * @param sandboxId Unique identifier for the sandbox
 * @param delegate The delegate instance to register (any type)
 */
- (void)register:(NSString *)sandboxId delegate:(id)delegate;

/**
 * Unregisters a delegate by ID.
 * @param sandboxId The ID of the sandbox to unregister
 */
- (void)unregister:(NSString *)sandboxId;

/**
 * Finds a delegate by ID.
 * @param sandboxId The ID of the sandbox to find
 * @return The registered delegate, or nil if not found
 */
- (nullable id)find:(NSString *)sandboxId;

@end

NS_ASSUME_NONNULL_END