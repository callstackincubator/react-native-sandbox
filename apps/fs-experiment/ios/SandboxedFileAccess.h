/**
 * Sandboxed FileAccess implementation for react-native-sandbox.
 *
 * Wraps the react-native-file-access module interface, scoping all file
 * operations to a per-origin sandbox directory. Constants (DocumentDir,
 * CacheDir, etc.) are overridden to point into the sandbox root.
 */

#import <React/RCTEventEmitter.h>
#import <React-Sandbox/RCTSandboxAwareModule.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import <RNFileAccessSpec/RNFileAccessSpec.h>

@interface SandboxedFileAccess : RCTEventEmitter <NativeFileAccessSpec, RCTSandboxAwareModule>
#else
#import <React/RCTBridgeModule.h>

@interface SandboxedFileAccess : RCTEventEmitter <RCTBridgeModule, RCTSandboxAwareModule>
#endif

@property (nonatomic, copy) NSString *sandboxRoot;

@end
