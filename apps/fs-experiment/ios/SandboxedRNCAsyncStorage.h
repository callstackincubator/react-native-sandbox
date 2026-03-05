/**
 * Sandboxed AsyncStorage implementation for react-native-sandbox.
 *
 * Based on RNCAsyncStorage from @react-native-async-storage/async-storage,
 * adapted to scope storage per sandbox origin. This module is intended to be
 * used as a TurboModule substitution target via turboModuleSubstitutions.
 *
 * When the sandbox requests "RNCAsyncStorage", this module can be resolved
 * instead, providing isolated key-value storage per sandbox origin.
 */

#import <Foundation/Foundation.h>

#import <React/RCTBridgeModule.h>
#import <React/RCTInvalidating.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import <rnasyncstorage/rnasyncstorage.h>
#endif

#import "RNCAsyncStorageDelegate.h"
#import <React-Sandbox/RCTSandboxAwareModule.h>

NS_ASSUME_NONNULL_BEGIN

@interface SandboxedRNCAsyncStorage : NSObject <
#ifdef RCT_NEW_ARCH_ENABLED
                                 NativeAsyncStorageModuleSpec
#else
                                 RCTBridgeModule
#endif
                                 ,
                                 RCTInvalidating,
                                 RCTSandboxAwareModule>

@property (nonatomic, weak, nullable) id<RNCAsyncStorageDelegate> delegate;
@property (nonatomic, assign) BOOL clearOnInvalidate;
@property (nonatomic, readonly, getter=isValid) BOOL valid;

/**
 * The storage directory for this instance. When created via default init,
 * this defaults to a "SandboxedAsyncStorage/default" directory.
 * The sandbox delegate's configureSandbox will update the storageDirectory
 * based on the sandbox origin BEFORE any storage operations are performed.
 */
@property (nonatomic, copy) NSString *storageDirectory;

- (instancetype)initWithStorageDirectory:(NSString *)storageDirectory;
- (void)clearAllData;
- (void)multiGet:(NSArray<NSString *> *)keys callback:(RCTResponseSenderBlock)callback;
- (void)multiSet:(NSArray<NSArray<NSString *> *> *)kvPairs callback:(RCTResponseSenderBlock)callback;
- (void)getAllKeys:(RCTResponseSenderBlock)callback;

@end

NS_ASSUME_NONNULL_END
