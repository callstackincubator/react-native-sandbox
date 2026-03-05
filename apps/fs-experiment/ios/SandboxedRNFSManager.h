/**
 * Sandboxed RNFSManager implementation for react-native-sandbox.
 *
 * Wraps the original RNFSManager from react-native-fs, scoping all file
 * operations to a per-origin sandbox directory. Exposed directory constants
 * (DocumentDirectoryPath, CachesDirectoryPath, etc.) are overridden to point
 * into the sandbox root.
 */

#import <Foundation/Foundation.h>

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <ReactCommon/RCTTurboModule.h>
#import <React-Sandbox/RCTSandboxAwareModule.h>

NS_ASSUME_NONNULL_BEGIN

@interface SandboxedRNFSManager : RCTEventEmitter <RCTBridgeModule, RCTTurboModule, RCTSandboxAwareModule>

@property (nonatomic, copy) NSString *sandboxRoot;

@end

NS_ASSUME_NONNULL_END
