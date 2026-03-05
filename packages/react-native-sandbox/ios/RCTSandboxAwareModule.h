#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * ObjC protocol equivalent of ISandboxAwareModule for ObjC TurboModules.
 *
 * When a TurboModule substitution resolves an ObjC module, the sandbox delegate
 * checks if the module conforms to this protocol and calls configureSandbox:
 * with context about the sandbox instance.
 *
 * @code
 * @interface SandboxedAsyncStorage : NSObject <NativeAsyncStorageModuleSpec, RCTSandboxAwareModule>
 * @end
 *
 * @implementation SandboxedAsyncStorage
 * - (void)configureSandboxWithOrigin:(NSString *)origin
 *                      requestedName:(NSString *)requestedName
 *                       resolvedName:(NSString *)resolvedName {
 *   self.storageDirectory = [basePath stringByAppendingPathComponent:origin];
 * }
 * @end
 * @endcode
 */
@protocol RCTSandboxAwareModule <NSObject>

/**
 * Called by the sandbox delegate after module instantiation to provide
 * sandbox-specific context.
 *
 * @param origin The sandbox origin identifier
 * @param requestedName The module name sandbox JS code requested
 * @param resolvedName The actual module name that was resolved
 */
- (void)configureSandboxWithOrigin:(NSString *)origin
                     requestedName:(NSString *)requestedName
                      resolvedName:(NSString *)resolvedName;

@end

NS_ASSUME_NONNULL_END
