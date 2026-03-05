/**
 * Sandboxed FileAccess — jails all file paths to a per-origin directory.
 *
 * Implements the NativeFileAccessSpec interface so JS code using
 * react-native-file-access works transparently inside a sandbox.
 */

#import "SandboxedFileAccess.h"

#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <CommonCrypto/CommonDigest.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import <ReactCommon/RCTTurboModule.h>
#endif

@implementation SandboxedFileAccess {
    NSString *_documentsDir;
    NSString *_cachesDir;
    NSString *_libraryDir;
    BOOL _configured;
}

RCT_EXPORT_MODULE(SandboxedFileAccess)

+ (BOOL)requiresMainQueueSetup { return NO; }

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"FetchResult"];
}

#pragma mark - Sandbox setup

- (void)_setupDirectoriesForOrigin:(NSString *)origin
{
    NSString *appSupport = NSSearchPathForDirectoriesInDomains(
        NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"com.unknown";
    _sandboxRoot = [[[appSupport stringByAppendingPathComponent:bundleId]
        stringByAppendingPathComponent:@"Sandboxes"]
        stringByAppendingPathComponent:origin];

    _documentsDir = [_sandboxRoot stringByAppendingPathComponent:@"Documents"];
    _cachesDir    = [_sandboxRoot stringByAppendingPathComponent:@"Caches"];
    _libraryDir   = [_sandboxRoot stringByAppendingPathComponent:@"Library"];

    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *dir in @[_documentsDir, _cachesDir, _libraryDir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    _configured = YES;
}

#pragma mark - RCTSandboxAwareModule

- (void)configureSandboxWithOrigin:(NSString *)origin
                     requestedName:(NSString *)requestedName
                      resolvedName:(NSString *)resolvedName
{
    NSLog(@"[SandboxedFileAccess] Configuring for origin '%@'", origin);
    [self _setupDirectoriesForOrigin:origin];
}

#pragma mark - Path validation

- (nullable NSString *)_sandboxedPath:(NSString *)path
                               reject:(RCTPromiseRejectBlock)reject
{
    if (!_configured) {
        reject(@"EPERM", @"SandboxedFileAccess: sandbox not configured. "
               "configureSandboxWithOrigin: must be called before any file operation.", nil);
        return nil;
    }

    NSString *resolved;
    if ([path hasPrefix:@"/"]) {
        resolved = [path stringByStandardizingPath];
    } else {
        resolved = [[_documentsDir stringByAppendingPathComponent:path] stringByStandardizingPath];
    }

    if ([resolved hasPrefix:_sandboxRoot]) {
        return resolved;
    }

    reject(@"EPERM", [NSString stringWithFormat:
        @"Path '%@' is outside the sandbox. Allowed root: %@", path, _sandboxRoot], nil);
    return nil;
}

#pragma mark - Constants

#ifdef RCT_NEW_ARCH_ENABLED
- (facebook::react::ModuleConstants<JS::NativeFileAccess::Constants::Builder>)constantsToExport
{
    return [self getConstants];
}

- (facebook::react::ModuleConstants<JS::NativeFileAccess::Constants::Builder>)getConstants
{
    if (!_configured) {
        return facebook::react::typedConstants<JS::NativeFileAccess::Constants::Builder>({
            .CacheDir = @"",
            .DocumentDir = @"",
            .LibraryDir = @"",
            .MainBundleDir = @"",
        });
    }
    return facebook::react::typedConstants<JS::NativeFileAccess::Constants::Builder>({
        .CacheDir = _cachesDir,
        .DocumentDir = _documentsDir,
        .LibraryDir = _libraryDir,
        .MainBundleDir = _documentsDir,
    });
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeFileAccessSpecJSI>(params);
}
#else
- (NSDictionary *)constantsToExport
{
    if (!_configured) {
        return @{};
    }
    return @{
        @"CacheDir": _cachesDir,
        @"DocumentDir": _documentsDir,
        @"LibraryDir": _libraryDir,
        @"MainBundleDir": _documentsDir,
    };
}
#endif

#pragma mark - File operations

RCT_EXPORT_METHOD(writeFile:(NSString *)path
                  data:(NSString *)data
                  encoding:(NSString *)encoding
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *safePath = [self _sandboxedPath:path reject:reject];
    if (!safePath) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        if ([encoding isEqualToString:@"base64"]) {
            NSData *decoded = [[NSData alloc] initWithBase64EncodedString:data
                                                                 options:NSDataBase64DecodingIgnoreUnknownCharacters];
            if (!decoded) {
                reject(@"ERR", [NSString stringWithFormat:@"Failed to write to '%@', invalid base64.", path], nil);
                return;
            }
            [decoded writeToFile:safePath options:NSDataWritingAtomic error:&error];
        } else {
            [data writeToFile:safePath atomically:NO encoding:NSUTF8StringEncoding error:&error];
        }
        if (error) {
            reject(@"ERR", [NSString stringWithFormat:@"Failed to write to '%@'. %@", path, error.localizedDescription], error);
        } else {
            resolve(nil);
        }
    });
}

RCT_EXPORT_METHOD(readFile:(NSString *)path
                  encoding:(NSString *)encoding
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *safePath = [self _sandboxedPath:path reject:reject];
    if (!safePath) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        if ([encoding isEqualToString:@"base64"]) {
            NSData *data = [NSData dataWithContentsOfFile:safePath options:0 error:&error];
            if (error || !data) {
                reject(@"ERR", [NSString stringWithFormat:@"Failed to read '%@'. %@", path,
                    error.localizedDescription ?: @""], error);
                return;
            }
            resolve([data base64EncodedStringWithOptions:0]);
        } else {
            NSString *content = [NSString stringWithContentsOfFile:safePath encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                reject(@"ERR", [NSString stringWithFormat:@"Failed to read '%@'. %@", path, error.localizedDescription], error);
                return;
            }
            resolve(content);
        }
    });
}

RCT_EXPORT_METHOD(readFileChunk:(NSString *)path
                  offset:(double)offset
                  length:(double)length
                  encoding:(NSString *)encoding
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *safePath = [self _sandboxedPath:path reject:reject];
    if (!safePath) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        NSFileHandle *fh = [NSFileHandle fileHandleForReadingFromURL:
            [NSURL fileURLWithPath:safePath] error:&error];
        if (error || !fh) {
            reject(@"ERR", [NSString stringWithFormat:@"Failed to read '%@'. %@", path,
                error.localizedDescription ?: @""], error);
            return;
        }

        [fh seekToFileOffset:(unsigned long long)offset];
        NSData *data = [fh readDataOfLength:(NSUInteger)length];
        [fh closeFile];

        if ([encoding isEqualToString:@"base64"]) {
            resolve([data base64EncodedStringWithOptions:0]);
        } else {
            NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (content) {
                resolve(content);
            } else {
                reject(@"ERR", @"Failed to decode content with specified encoding.", nil);
            }
        }
    });
}

RCT_EXPORT_METHOD(appendFile:(NSString *)path
                  data:(NSString *)data
                  encoding:(NSString *)encoding
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *safePath = [self _sandboxedPath:path reject:reject];
    if (!safePath) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *encoded = [encoding isEqualToString:@"base64"]
            ? [[NSData alloc] initWithBase64EncodedString:data options:NSDataBase64DecodingIgnoreUnknownCharacters]
            : [data dataUsingEncoding:NSUTF8StringEncoding];

        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:safePath];
        if (!fh) {
            reject(@"ERR", [NSString stringWithFormat:@"Failed to append to '%@'.", path], nil);
            return;
        }
        [fh seekToEndOfFile];
        [fh writeData:encoded];
        [fh closeFile];
        resolve(nil);
    });
}

RCT_EXPORT_METHOD(exists:(NSString *)path
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *safePath = [self _sandboxedPath:path reject:reject];
    if (!safePath) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        resolve(@([[NSFileManager defaultManager] fileExistsAtPath:safePath]));
    });
}

RCT_EXPORT_METHOD(isDir:(NSString *)path
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *safePath = [self _sandboxedPath:path reject:reject];
    if (!safePath) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL isDir = NO;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:safePath isDirectory:&isDir];
        resolve(@(exists && isDir));
    });
}

RCT_EXPORT_METHOD(ls:(NSString *)path
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *safePath = [self _sandboxedPath:path reject:reject];
    if (!safePath) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:safePath error:&error];
        if (error) {
            reject(@"ERR", [NSString stringWithFormat:@"Failed to list '%@'. %@", path, error.localizedDescription], error);
            return;
        }
        resolve(contents);
    });
}

RCT_EXPORT_METHOD(mkdir:(NSString *)path
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *safePath = [self _sandboxedPath:path reject:reject];
    if (!safePath) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:safePath
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error]) {
            reject(@"ERR", [NSString stringWithFormat:@"Failed to create '%@'. %@", path, error.localizedDescription], error);
            return;
        }
        resolve(safePath);
    });
}

RCT_EXPORT_METHOD(cp:(NSString *)source
                  target:(NSString *)target
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *src = [self _sandboxedPath:source reject:reject];
    if (!src) return;
    NSString *dst = [self _sandboxedPath:target reject:reject];
    if (!dst) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        if (![[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:&error]) {
            reject(@"ERR", [NSString stringWithFormat:@"Failed to copy '%@' to '%@'. %@",
                source, target, error.localizedDescription], error);
            return;
        }
        resolve(nil);
    });
}

RCT_EXPORT_METHOD(mv:(NSString *)source
                  target:(NSString *)target
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *src = [self _sandboxedPath:source reject:reject];
    if (!src) return;
    NSString *dst = [self _sandboxedPath:target reject:reject];
    if (!dst) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:dst error:nil];
        if (![[NSFileManager defaultManager] moveItemAtPath:src toPath:dst error:&error]) {
            reject(@"ERR", [NSString stringWithFormat:@"Failed to move '%@' to '%@'. %@",
                source, target, error.localizedDescription], error);
            return;
        }
        resolve(nil);
    });
}

RCT_EXPORT_METHOD(unlink:(NSString *)path
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *safePath = [self _sandboxedPath:path reject:reject];
    if (!safePath) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        if (![[NSFileManager defaultManager] removeItemAtPath:safePath error:&error]) {
            reject(@"ERR", [NSString stringWithFormat:@"Failed to unlink '%@'. %@", path, error.localizedDescription], error);
            return;
        }
        resolve(nil);
    });
}

RCT_EXPORT_METHOD(stat:(NSString *)path
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *safePath = [self _sandboxedPath:path reject:reject];
    if (!safePath) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:safePath error:&error];
        if (error) {
            reject(@"ERR", [NSString stringWithFormat:@"Failed to stat '%@'. %@", path, error.localizedDescription], error);
            return;
        }

        NSURL *pathUrl = [NSURL fileURLWithPath:safePath];
        BOOL isDir = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:safePath isDirectory:&isDir];

        resolve(@{
            @"filename": pathUrl.lastPathComponent ?: @"",
            @"lastModified": @(1000.0 * [(NSDate *)attrs[NSFileModificationDate] timeIntervalSince1970]),
            @"path": safePath,
            @"size": attrs[NSFileSize] ?: @0,
            @"type": isDir ? @"directory" : @"file",
        });
    });
}

RCT_EXPORT_METHOD(statDir:(NSString *)path
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *safePath = [self _sandboxedPath:path reject:reject];
    if (!safePath) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:safePath error:&error];
        if (error) {
            reject(@"ERR", [NSString stringWithFormat:@"Failed to list '%@'. %@", path, error.localizedDescription], error);
            return;
        }

        NSMutableArray *results = [NSMutableArray new];
        for (NSString *name in contents) {
            NSString *fullPath = [safePath stringByAppendingPathComponent:name];
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:nil];
            if (!attrs) continue;

            BOOL isDir = NO;
            [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir];

            [results addObject:@{
                @"filename": name,
                @"lastModified": @(1000.0 * [(NSDate *)attrs[NSFileModificationDate] timeIntervalSince1970]),
                @"path": fullPath,
                @"size": attrs[NSFileSize] ?: @0,
                @"type": isDir ? @"directory" : @"file",
            }];
        }
        resolve(results);
    });
}

RCT_EXPORT_METHOD(hash:(NSString *)path
                  algorithm:(NSString *)algorithm
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *safePath = [self _sandboxedPath:path reject:reject];
    if (!safePath) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfFile:safePath];
        if (!data) {
            reject(@"ERR", [NSString stringWithFormat:@"Failed to read '%@'.", path], nil);
            return;
        }

        unsigned char buffer[CC_SHA512_DIGEST_LENGTH];
        int digestLength;

        if ([algorithm isEqualToString:@"MD5"]) {
            digestLength = CC_MD5_DIGEST_LENGTH;
            CC_MD5(data.bytes, (CC_LONG)data.length, buffer);
        } else if ([algorithm isEqualToString:@"SHA-1"]) {
            digestLength = CC_SHA1_DIGEST_LENGTH;
            CC_SHA1(data.bytes, (CC_LONG)data.length, buffer);
        } else if ([algorithm isEqualToString:@"SHA-256"]) {
            digestLength = CC_SHA256_DIGEST_LENGTH;
            CC_SHA256(data.bytes, (CC_LONG)data.length, buffer);
        } else if ([algorithm isEqualToString:@"SHA-512"]) {
            digestLength = CC_SHA512_DIGEST_LENGTH;
            CC_SHA512(data.bytes, (CC_LONG)data.length, buffer);
        } else {
            reject(@"ERR", [NSString stringWithFormat:@"Unknown algorithm '%@'.", algorithm], nil);
            return;
        }

        NSMutableString *output = [NSMutableString stringWithCapacity:digestLength * 2];
        for (int i = 0; i < digestLength; i++) {
            [output appendFormat:@"%02x", buffer[i]];
        }
        resolve(output);
    });
}

RCT_EXPORT_METHOD(concatFiles:(NSString *)source
                  target:(NSString *)target
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *src = [self _sandboxedPath:source reject:reject];
    if (!src) return;
    NSString *dst = [self _sandboxedPath:target reject:reject];
    if (!dst) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSInputStream *input = [NSInputStream inputStreamWithFileAtPath:src];
        NSOutputStream *output = [NSOutputStream outputStreamToFileAtPath:dst append:YES];
        if (!input || !output) {
            reject(@"ERR", [NSString stringWithFormat:@"Failed to concat '%@' to '%@'.", source, target], nil);
            return;
        }

        [input open];
        [output open];
        NSInteger totalBytes = 0;
        uint8_t buf[8192];
        NSInteger len;
        while ((len = [input read:buf maxLength:sizeof(buf)]) > 0) {
            [output write:buf maxLength:len];
            totalBytes += len;
        }
        [output close];
        [input close];
        resolve(@(totalBytes));
    });
}

RCT_EXPORT_METHOD(df:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        NSDictionary *attrs = [[NSFileManager defaultManager]
            attributesOfFileSystemForPath:self->_sandboxRoot error:&error];
        if (error) {
            reject(@"ERR", [NSString stringWithFormat:@"Failed to stat filesystem. %@", error.localizedDescription], error);
            return;
        }
        resolve(@{
            @"internal_free": attrs[NSFileSystemFreeSize],
            @"internal_total": attrs[NSFileSystemSize],
        });
    });
}

#pragma mark - Blocked operations

#ifdef RCT_NEW_ARCH_ENABLED
RCT_EXPORT_METHOD(fetch:(double)requestId
                  resource:(NSString *)resource
                  init:(JS::NativeFileAccess::SpecFetchInit &)init)
{
    RCTLogWarn(@"[SandboxedFileAccess] fetch is not available in sandboxed mode");
}
#else
RCT_EXPORT_METHOD(fetch:(double)requestId
                  resource:(NSString *)resource
                  init:(NSDictionary *)init)
{
    RCTLogWarn(@"[SandboxedFileAccess] fetch is not available in sandboxed mode");
}
#endif

RCT_EXPORT_METHOD(cancelFetch:(double)requestId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    resolve(nil);
}

RCT_EXPORT_METHOD(cpAsset:(NSString *)asset
                  target:(NSString *)target
                  type:(NSString *)type
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    reject(@"EPERM", @"cpAsset is not available in sandboxed mode", nil);
}

RCT_EXPORT_METHOD(cpExternal:(NSString *)source
                  targetName:(NSString *)targetName
                  dir:(NSString *)dir
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    reject(@"EPERM", @"cpExternal is not available in sandboxed mode", nil);
}

RCT_EXPORT_METHOD(getAppGroupDir:(NSString *)groupName
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    reject(@"EPERM", @"getAppGroupDir is not available in sandboxed mode", nil);
}

RCT_EXPORT_METHOD(unzip:(NSString *)source
                  target:(NSString *)target
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSString *src = [self _sandboxedPath:source reject:reject];
    if (!src) return;
    NSString *dst = [self _sandboxedPath:target reject:reject];
    if (!dst) return;

    reject(@"EPERM", @"unzip is not available in sandboxed mode", nil);
}

RCT_EXPORT_METHOD(hardlink:(NSString *)source
                  target:(NSString *)target
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    reject(@"EPERM", @"hardlink is not available in sandboxed mode", nil);
}

RCT_EXPORT_METHOD(symlink:(NSString *)source
                  target:(NSString *)target
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    reject(@"EPERM", @"symlink is not available in sandboxed mode", nil);
}

// Required by RCTEventEmitter
RCT_EXPORT_METHOD(addListener:(NSString *)eventName) {}
RCT_EXPORT_METHOD(removeListeners:(double)count) {}

@end
