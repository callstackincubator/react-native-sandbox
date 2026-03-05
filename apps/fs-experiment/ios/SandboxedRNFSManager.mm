/**
 * Sandboxed RNFSManager — jails all file paths to a per-origin directory.
 *
 * Every path argument is validated against the sandbox root. Directory
 * constants exposed to JS (RNFSDocumentDirectoryPath, etc.) are overridden.
 */

#import "SandboxedRNFSManager.h"

#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <ReactCommon/RCTInteropTurboModule.h>
#import <CommonCrypto/CommonDigest.h>

@implementation SandboxedRNFSManager {
    dispatch_queue_t _methodQueue;
    NSString *_documentsDir;
    NSString *_cachesDir;
    NSString *_tempDir;
    NSString *_libraryDir;
    BOOL _configured;
}

RCT_EXPORT_MODULE(SandboxedRNFSManager)

+ (BOOL)requiresMainQueueSetup { return NO; }

- (dispatch_queue_t)methodQueue
{
    if (!_methodQueue) {
        _methodQueue = dispatch_queue_create("sandbox.rnfs", DISPATCH_QUEUE_SERIAL);
    }
    return _methodQueue;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"DownloadBegin", @"DownloadProgress", @"DownloadResumable",
             @"UploadBegin", @"UploadProgress"];
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
    _tempDir      = [_sandboxRoot stringByAppendingPathComponent:@"tmp"];
    _libraryDir   = [_sandboxRoot stringByAppendingPathComponent:@"Library"];

    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *dir in @[_documentsDir, _cachesDir, _tempDir, _libraryDir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    _configured = YES;
}

#pragma mark - RCTSandboxAwareModule

- (void)configureSandboxWithOrigin:(NSString *)origin
                     requestedName:(NSString *)requestedName
                      resolvedName:(NSString *)resolvedName
{
    NSLog(@"[SandboxedRNFSManager] Configuring for origin '%@'", origin);
    [self _setupDirectoriesForOrigin:origin];
}

#pragma mark - Path validation

- (nullable NSString *)_sandboxedPath:(NSString *)path
                               reject:(RCTPromiseRejectBlock)reject
{
    if (!_configured) {
        reject(@"EPERM", @"SandboxedRNFSManager: sandbox not configured. "
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

- (nullable NSString *)_sandboxedSrcPath:(NSString *)path
                                  reject:(RCTPromiseRejectBlock)reject
{
    return [self _sandboxedPath:path reject:reject];
}

#pragma mark - Constants

- (NSDictionary *)constantsToExport
{
    if (!_configured) {
        return @{};
    }
    return @{
        @"RNFSMainBundlePath":            _documentsDir, // no access to real main bundle
        @"RNFSCachesDirectoryPath":        _cachesDir,
        @"RNFSDocumentDirectoryPath":      _documentsDir,
        @"RNFSExternalDirectoryPath":      [NSNull null],
        @"RNFSExternalStorageDirectoryPath": [NSNull null],
        @"RNFSExternalCachesDirectoryPath": [NSNull null],
        @"RNFSDownloadDirectoryPath":      [NSNull null],
        @"RNFSTemporaryDirectoryPath":     _tempDir,
        @"RNFSLibraryDirectoryPath":       _libraryDir,
        @"RNFSPicturesDirectoryPath":      [NSNull null],
        @"RNFSFileTypeRegular":            NSFileTypeRegular,
        @"RNFSFileTypeDirectory":          NSFileTypeDirectory,
        @"RNFSFileProtectionComplete":     NSFileProtectionComplete,
        @"RNFSFileProtectionCompleteUnlessOpen": NSFileProtectionCompleteUnlessOpen,
        @"RNFSFileProtectionCompleteUntilFirstUserAuthentication": NSFileProtectionCompleteUntilFirstUserAuthentication,
        @"RNFSFileProtectionNone":         NSFileProtectionNone,
    };
}

#pragma mark - File operations

RCT_EXPORT_METHOD(writeFile:(NSString *)filepath
                  contents:(NSString *)base64Content
                  options:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *path = [self _sandboxedPath:filepath reject:reject];
    if (!path) return;

    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64Content
                                                       options:NSDataBase64DecodingIgnoreUnknownCharacters];
    BOOL success = [[NSFileManager defaultManager] createFileAtPath:path contents:data attributes:nil];
    if (!success) {
        reject(@"ENOENT", [NSString stringWithFormat:@"ENOENT: could not write '%@'", path], nil);
        return;
    }
    resolve(nil);
}

RCT_EXPORT_METHOD(readFile:(NSString *)filepath
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *path = [self _sandboxedPath:filepath reject:reject];
    if (!path) return;

    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        reject(@"ENOENT", [NSString stringWithFormat:@"ENOENT: no such file '%@'", path], nil);
        return;
    }
    NSData *content = [[NSFileManager defaultManager] contentsAtPath:path];
    resolve([content base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed]);
}

RCT_EXPORT_METHOD(readDir:(NSString *)dirPath
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *path = [self _sandboxedPath:dirPath reject:reject];
    if (!path) return;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    NSArray *contents = [fm contentsOfDirectoryAtPath:path error:&error];
    if (error) {
        reject(@"ENOENT", error.localizedDescription, error);
        return;
    }

    NSMutableArray *result = [NSMutableArray new];
    for (NSString *name in contents) {
        NSString *fullPath = [path stringByAppendingPathComponent:name];
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        if (attrs) {
            [result addObject:@{
                @"ctime": @([(NSDate *)attrs[NSFileCreationDate] timeIntervalSince1970]),
                @"mtime": @([(NSDate *)attrs[NSFileModificationDate] timeIntervalSince1970]),
                @"name": name,
                @"path": fullPath,
                @"size": attrs[NSFileSize],
                @"type": attrs[NSFileType],
            }];
        }
    }
    resolve(result);
}

RCT_EXPORT_METHOD(exists:(NSString *)filepath
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *path = [self _sandboxedPath:filepath reject:reject];
    if (!path) return;
    resolve(@([[NSFileManager defaultManager] fileExistsAtPath:path]));
}

RCT_EXPORT_METHOD(stat:(NSString *)filepath
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *path = [self _sandboxedPath:filepath reject:reject];
    if (!path) return;

    NSError *error;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
    if (error) {
        reject(@"ENOENT", error.localizedDescription, error);
        return;
    }

    resolve(@{
        @"ctime": @([(NSDate *)attrs[NSFileCreationDate] timeIntervalSince1970]),
        @"mtime": @([(NSDate *)attrs[NSFileModificationDate] timeIntervalSince1970]),
        @"size": attrs[NSFileSize],
        @"type": attrs[NSFileType],
        @"mode": @([[(NSNumber *)attrs[NSFilePosixPermissions] stringValue] integerValue]),
    });
}

RCT_EXPORT_METHOD(unlink:(NSString *)filepath
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *path = [self _sandboxedPath:filepath reject:reject];
    if (!path) return;

    NSError *error;
    if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
        reject(@"ENOENT", error.localizedDescription, error);
        return;
    }
    resolve(nil);
}

RCT_EXPORT_METHOD(mkdir:(NSString *)filepath
                  options:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *path = [self _sandboxedPath:filepath reject:reject];
    if (!path) return;

    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:path
                                   withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error]) {
        reject(@"ENOENT", error.localizedDescription, error);
        return;
    }
    resolve(nil);
}

RCT_EXPORT_METHOD(moveFile:(NSString *)filepath
                  destPath:(NSString *)destPath
                  options:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *src = [self _sandboxedPath:filepath reject:reject];
    if (!src) return;
    NSString *dst = [self _sandboxedPath:destPath reject:reject];
    if (!dst) return;

    NSError *error;
    if (![[NSFileManager defaultManager] moveItemAtPath:src toPath:dst error:&error]) {
        reject(@"ENOENT", error.localizedDescription, error);
        return;
    }
    resolve(nil);
}

RCT_EXPORT_METHOD(copyFile:(NSString *)filepath
                  destPath:(NSString *)destPath
                  options:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *src = [self _sandboxedPath:filepath reject:reject];
    if (!src) return;
    NSString *dst = [self _sandboxedPath:destPath reject:reject];
    if (!dst) return;

    NSError *error;
    if (![[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:&error]) {
        reject(@"ENOENT", error.localizedDescription, error);
        return;
    }
    resolve(nil);
}

RCT_EXPORT_METHOD(appendFile:(NSString *)filepath
                  contents:(NSString *)base64Content
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *path = [self _sandboxedPath:filepath reject:reject];
    if (!path) return;

    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64Content
                                                       options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        if (![fm createFileAtPath:path contents:data attributes:nil]) {
            reject(@"ENOENT", [NSString stringWithFormat:@"ENOENT: could not create '%@'", path], nil);
            return;
        }
        resolve(nil);
        return;
    }

    @try {
        NSFileHandle *fh = [NSFileHandle fileHandleForUpdatingAtPath:path];
        [fh seekToEndOfFile];
        [fh writeData:data];
        resolve(nil);
    } @catch (NSException *e) {
        reject(@"ENOENT", e.reason, nil);
    }
}

RCT_EXPORT_METHOD(write:(NSString *)filepath
                  contents:(NSString *)base64Content
                  position:(NSInteger)position
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *path = [self _sandboxedPath:filepath reject:reject];
    if (!path) return;

    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64Content
                                                       options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        if (![fm createFileAtPath:path contents:data attributes:nil]) {
            reject(@"ENOENT", [NSString stringWithFormat:@"ENOENT: could not create '%@'", path], nil);
            return;
        }
        resolve(nil);
        return;
    }

    @try {
        NSFileHandle *fh = [NSFileHandle fileHandleForUpdatingAtPath:path];
        if (position >= 0) {
            [fh seekToFileOffset:position];
        } else {
            [fh seekToEndOfFile];
        }
        [fh writeData:data];
        resolve(nil);
    } @catch (NSException *e) {
        reject(@"ENOENT", e.reason, nil);
    }
}

RCT_EXPORT_METHOD(read:(NSString *)filepath
                  length:(NSInteger)length
                  position:(NSInteger)position
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *path = [self _sandboxedPath:filepath reject:reject];
    if (!path) return;

    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        reject(@"ENOENT", [NSString stringWithFormat:@"ENOENT: no such file '%@'", path], nil);
        return;
    }

    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!fh) {
        reject(@"ENOENT", @"Could not open file for reading", nil);
        return;
    }
    [fh seekToFileOffset:(unsigned long long)position];
    NSData *content = (length > 0) ? [fh readDataOfLength:length] : [fh readDataToEndOfFile];
    resolve([content base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed]);
}

RCT_EXPORT_METHOD(hash:(NSString *)filepath
                  algorithm:(NSString *)algorithm
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *path = [self _sandboxedPath:filepath reject:reject];
    if (!path) return;

    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        reject(@"ENOENT", [NSString stringWithFormat:@"ENOENT: no such file '%@'", path], nil);
        return;
    }

    NSData *content = [[NSFileManager defaultManager] contentsAtPath:path];

    NSDictionary *digestLengths = @{
        @"md5":    @(CC_MD5_DIGEST_LENGTH),
        @"sha1":   @(CC_SHA1_DIGEST_LENGTH),
        @"sha224": @(CC_SHA224_DIGEST_LENGTH),
        @"sha256": @(CC_SHA256_DIGEST_LENGTH),
        @"sha384": @(CC_SHA384_DIGEST_LENGTH),
        @"sha512": @(CC_SHA512_DIGEST_LENGTH),
    };

    int digestLength = [digestLengths[algorithm] intValue];
    if (!digestLength) {
        reject(@"Error", [NSString stringWithFormat:@"Invalid hash algorithm '%@'", algorithm], nil);
        return;
    }

    unsigned char buffer[CC_SHA512_DIGEST_LENGTH];
    if ([algorithm isEqualToString:@"md5"])         CC_MD5(content.bytes, (CC_LONG)content.length, buffer);
    else if ([algorithm isEqualToString:@"sha1"])   CC_SHA1(content.bytes, (CC_LONG)content.length, buffer);
    else if ([algorithm isEqualToString:@"sha224"]) CC_SHA224(content.bytes, (CC_LONG)content.length, buffer);
    else if ([algorithm isEqualToString:@"sha256"]) CC_SHA256(content.bytes, (CC_LONG)content.length, buffer);
    else if ([algorithm isEqualToString:@"sha384"]) CC_SHA384(content.bytes, (CC_LONG)content.length, buffer);
    else if ([algorithm isEqualToString:@"sha512"]) CC_SHA512(content.bytes, (CC_LONG)content.length, buffer);

    NSMutableString *output = [NSMutableString stringWithCapacity:digestLength * 2];
    for (int i = 0; i < digestLength; i++) {
        [output appendFormat:@"%02x", buffer[i]];
    }
    resolve(output);
}

RCT_EXPORT_METHOD(getFSInfo:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSError *error;
    NSDictionary *attrs = [[NSFileManager defaultManager]
        attributesOfFileSystemForPath:_sandboxRoot error:&error];
    if (error) {
        reject(@"Error", error.localizedDescription, error);
        return;
    }
    resolve(@{
        @"totalSpace": attrs[NSFileSystemSize],
        @"freeSpace": attrs[NSFileSystemFreeSize],
    });
}

RCT_EXPORT_METHOD(touch:(NSString *)filepath
                  mtime:(NSDate *)mtime
                  ctime:(NSDate *)ctime
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *path = [self _sandboxedPath:filepath reject:reject];
    if (!path) return;

    NSMutableDictionary *attr = [NSMutableDictionary new];
    if (mtime) attr[NSFileModificationDate] = mtime;
    if (ctime) attr[NSFileCreationDate] = ctime;

    NSError *error;
    if (![[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:path error:&error]) {
        reject(@"ENOENT", error.localizedDescription, error);
        return;
    }
    resolve(nil);
}

#pragma mark - Stubbed network operations (blocked in sandbox)

RCT_EXPORT_METHOD(downloadFile:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    reject(@"EPERM", @"downloadFile is not available in sandboxed mode", nil);
}

RCT_EXPORT_METHOD(stopDownload:(nonnull NSNumber *)jobId)
{
    RCTLogWarn(@"[SandboxedRNFSManager] stopDownload blocked in sandbox");
}

RCT_EXPORT_METHOD(resumeDownload:(nonnull NSNumber *)jobId)
{
    RCTLogWarn(@"[SandboxedRNFSManager] resumeDownload blocked in sandbox");
}

RCT_EXPORT_METHOD(isResumable:(nonnull NSNumber *)jobId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    resolve(@NO);
}

RCT_EXPORT_METHOD(uploadFiles:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    reject(@"EPERM", @"uploadFiles is not available in sandboxed mode", nil);
}

RCT_EXPORT_METHOD(stopUpload:(nonnull NSNumber *)jobId)
{
    RCTLogWarn(@"[SandboxedRNFSManager] stopUpload blocked in sandbox");
}

RCT_EXPORT_METHOD(completeHandlerIOS:(nonnull NSNumber *)jobId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    resolve(nil);
}

RCT_EXPORT_METHOD(pathForBundle:(NSString *)bundleNamed
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    reject(@"EPERM", @"pathForBundle is not available in sandboxed mode", nil);
}

RCT_EXPORT_METHOD(pathForGroup:(NSString *)groupId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    reject(@"EPERM", @"pathForGroup is not available in sandboxed mode", nil);
}

// addListener / removeListeners required by RCTEventEmitter
RCT_EXPORT_METHOD(addListener:(NSString *)eventName) {}
RCT_EXPORT_METHOD(removeListeners:(double)count) {}

#pragma mark - RCTTurboModule

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::ObjCInteropTurboModule>(params);
}

@end
