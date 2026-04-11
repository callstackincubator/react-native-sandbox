/**
 * Sandboxed AsyncStorage implementation for react-native-sandbox.
 *
 * Based on the original RNCAsyncStorage from @react-native-async-storage/async-storage.
 * Scopes all storage to a per-origin directory to prevent data leaks between sandboxes.
 */

#import "SandboxedRNCAsyncStorage.h"

#import <React/RCTConvert.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>

static NSString *const RCTManifestFileName = @"manifest.json";
static const NSUInteger RCTInlineValueThreshold = 1024;

#pragma mark - Static helper functions

static NSDictionary *RCTErrorForKey(NSString *key)
{
    if (![key isKindOfClass:[NSString class]]) {
        return RCTMakeAndLogError(@"Invalid key - must be a string.  Key: ", key, @{@"key": key});
    } else if (key.length < 1) {
        return RCTMakeAndLogError(
            @"Invalid key - must be at least one character.  Key: ", key, @{@"key": key});
    } else {
        return nil;
    }
}

static void RCTAppendError(NSDictionary *error, NSMutableArray<NSDictionary *> **errors)
{
    if (error && errors) {
        if (!*errors) {
            *errors = [NSMutableArray new];
        }
        [*errors addObject:error];
    }
}

static NSArray<NSDictionary *> *RCTMakeErrors(NSArray<id<NSObject>> *results)
{
    NSMutableArray<NSDictionary *> *errors;
    for (id object in results) {
        if ([object isKindOfClass:[NSError class]]) {
            NSError *error = (NSError *)object;
            NSDictionary *keyError = RCTMakeError(error.localizedDescription, error, nil);
            RCTAppendError(keyError, &errors);
        }
    }
    return errors;
}

static NSString *RCTReadFile(NSString *filePath, NSString *key, NSDictionary **errorOut)
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSError *error;
        NSStringEncoding encoding;
        NSString *entryString = [NSString stringWithContentsOfFile:filePath
                                                      usedEncoding:&encoding
                                                             error:&error];
        NSDictionary *extraData = @{@"key": RCTNullIfNil(key)};

        if (error) {
            if (errorOut) {
                *errorOut = RCTMakeError(@"Failed to read storage file.", error, extraData);
            }
            return nil;
        }

        if (encoding != NSUTF8StringEncoding) {
            if (errorOut) {
                *errorOut =
                    RCTMakeError(@"Incorrect encoding of storage file: ", @(encoding), extraData);
            }
            return nil;
        }
        return entryString;
    }

    return nil;
}

static BOOL RCTMergeRecursive(NSMutableDictionary *destination, NSDictionary *source)
{
    BOOL modified = NO;
    for (NSString *key in source) {
        id sourceValue = source[key];
        id destinationValue = destination[key];
        if ([sourceValue isKindOfClass:[NSDictionary class]]) {
            if ([destinationValue isKindOfClass:[NSDictionary class]]) {
                if ([destinationValue classForCoder] != [NSMutableDictionary class]) {
                    destinationValue = [destinationValue mutableCopy];
                }
                if (RCTMergeRecursive(destinationValue, sourceValue)) {
                    destination[key] = destinationValue;
                    modified = YES;
                }
            } else {
                destination[key] = [sourceValue copy];
                modified = YES;
            }
        } else if (![source isEqual:destinationValue]) {
            destination[key] = [sourceValue copy];
            modified = YES;
        }
    }
    return modified;
}

#define RCTGetStorageDirectory() _storageDirectory
#define RCTGetManifestFilePath() _manifestFilePath
#define RCTGetMethodQueue() self.methodQueue
#define RCTGetCache() self.cache

static NSDictionary *RCTDeleteStorageDirectory(NSString *storageDirectory)
{
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:storageDirectory error:&error];
    return error ? RCTMakeError(@"Failed to delete storage directory.", error, nil) : nil;
}

#define RCTDeleteStorageDirectory() RCTDeleteStorageDirectory(_storageDirectory)

#pragma mark - SandboxedRNCAsyncStorage

@interface SandboxedRNCAsyncStorage ()

@property (nonatomic, copy) NSString *manifestFilePath;

@end

@implementation SandboxedRNCAsyncStorage {
    BOOL _haveSetup;
    BOOL _configured;
    NSMutableDictionary<NSString *, NSString *> *_manifest;
    NSCache *_cache;
    dispatch_once_t _cacheOnceToken;
}

RCT_EXPORT_MODULE(SandboxedAsyncStorage)

- (instancetype)initWithStorageDirectory:(NSString *)storageDirectory
{
    if ((self = [super init])) {
        _storageDirectory = storageDirectory;
        _manifestFilePath = [_storageDirectory stringByAppendingPathComponent:RCTManifestFileName];
        _configured = YES;
    }
    return self;
}

@synthesize methodQueue = _methodQueue;

- (void)setStorageDirectory:(NSString *)storageDirectory
{
    _storageDirectory = [storageDirectory copy];
    _manifestFilePath = [_storageDirectory stringByAppendingPathComponent:RCTManifestFileName];
    _haveSetup = NO;
    [_manifest removeAllObjects];
    [_cache removeAllObjects];
}

- (NSCache *)cache
{
    dispatch_once(&_cacheOnceToken, ^{
        _cache = [NSCache new];
        _cache.totalCostLimit = 2 * 1024 * 1024; // 2MB

        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                       object:nil
                        queue:nil
                   usingBlock:^(__unused NSNotification *note) {
                     [self->_cache removeAllObjects];
                   }];
    });
    return _cache;
}

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _configured = NO;
    }
    return self;
}

- (void)clearAllData
{
    dispatch_async(RCTGetMethodQueue(), ^{
        [self->_manifest removeAllObjects];
        [RCTGetCache() removeAllObjects];
        RCTDeleteStorageDirectory();
    });
}

- (void)invalidate
{
    if (_clearOnInvalidate) {
        [RCTGetCache() removeAllObjects];
        RCTDeleteStorageDirectory();
    }
    _clearOnInvalidate = NO;
    [_manifest removeAllObjects];
    _haveSetup = NO;
}

- (BOOL)isValid
{
    return _haveSetup;
}

- (void)dealloc
{
    [self invalidate];
}

- (NSString *)_filePathForKey:(NSString *)key
{
    NSString *safeFileName = RCTMD5Hash(key);
    return [RCTGetStorageDirectory() stringByAppendingPathComponent:safeFileName];
}

- (NSDictionary *)_ensureSetup
{
    RCTAssertThread(RCTGetMethodQueue(), @"Must be executed on storage thread");

    if (!_configured) {
        return RCTMakeError(@"SandboxedAsyncStorage: sandbox not configured. "
                            "configureSandboxWithOrigin: must be called before any storage operation.", nil, nil);
    }

    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:RCTGetStorageDirectory()
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if (error) {
        return RCTMakeError(@"Failed to create storage directory.", error, nil);
    }

    if (!_haveSetup) {
        NSDictionary *errorOut = nil;
        NSString *serialized = RCTReadFile(RCTGetManifestFilePath(), RCTManifestFileName, &errorOut);
        if (!serialized) {
            if (errorOut) {
                RCTLogError(@"Could not open the existing manifest: %@", errorOut);
                return errorOut;
            } else {
                _manifest = [NSMutableDictionary new];
            }
        } else {
            _manifest = RCTJSONParseMutable(serialized, &error);
            if (!_manifest) {
                RCTLogError(@"Failed to parse manifest - creating a new one: %@", error);
                _manifest = [NSMutableDictionary new];
            }
        }
        _haveSetup = YES;
    }

    return nil;
}

- (NSDictionary *)_writeManifest:(NSMutableArray<NSDictionary *> *__autoreleasing *)errors
{
    NSError *error;
    NSString *serialized = RCTJSONStringify(_manifest, &error);
    [serialized writeToFile:RCTGetManifestFilePath()
                 atomically:YES
                   encoding:NSUTF8StringEncoding
                      error:&error];
    NSDictionary *errorOut;
    if (error) {
        errorOut = RCTMakeError(@"Failed to write manifest file.", error, nil);
        RCTAppendError(errorOut, errors);
    }
    return errorOut;
}

- (NSString *)_getValueForKey:(NSString *)key errorOut:(NSDictionary *__autoreleasing *)errorOut
{
    NSString *value = _manifest[key];
    if (value == (id)kCFNull) {
        value = [RCTGetCache() objectForKey:key];
        if (!value) {
            NSString *filePath = [self _filePathForKey:key];
            value = RCTReadFile(filePath, key, errorOut);
            if (value) {
                [RCTGetCache() setObject:value forKey:key cost:value.length];
            } else {
                [_manifest removeObjectForKey:key];
            }
        }
    }
    return value;
}

- (NSDictionary *)_writeEntry:(NSArray<NSString *> *)entry changedManifest:(BOOL *)changedManifest
{
    if (entry.count != 2) {
        return RCTMakeAndLogError(
            @"Entries must be arrays of the form [key: string, value: string], got: ", entry, nil);
    }
    NSString *key = entry[0];
    NSDictionary *errorOut = RCTErrorForKey(key);
    if (errorOut) {
        return errorOut;
    }
    NSString *value = entry[1];
    NSString *filePath = [self _filePathForKey:key];
    NSError *error;
    if (value.length <= RCTInlineValueThreshold) {
        if (_manifest[key] == (id)kCFNull) {
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            [RCTGetCache() removeObjectForKey:key];
        }
        *changedManifest = YES;
        _manifest[key] = value;
        return nil;
    }
    [value writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    [RCTGetCache() setObject:value forKey:key cost:value.length];
    if (error) {
        errorOut = RCTMakeError(@"Failed to write value.", error, @{@"key": key});
    } else if (_manifest[key] != (id)kCFNull) {
        *changedManifest = YES;
        _manifest[key] = (id)kCFNull;
    }
    return errorOut;
}

- (void)_multiGet:(NSArray<NSString *> *)keys
         callback:(RCTResponseSenderBlock)callback
           getter:(NSString * (^)(NSUInteger i, NSString *key, NSDictionary **errorOut))getValue
{
    NSMutableArray<NSDictionary *> *errors;
    NSMutableArray<NSArray<NSString *> *> *result = [NSMutableArray arrayWithCapacity:keys.count];
    for (NSUInteger i = 0; i < keys.count; ++i) {
        NSString *key = keys[i];
        id keyError;
        id value = getValue(i, key, &keyError);
        [result addObject:@[key, RCTNullIfNil(value)]];
        RCTAppendError(keyError, &errors);
    }
    callback(@[RCTNullIfNil(errors), result]);
}

- (BOOL)_passthroughDelegate
{
    return
        [self.delegate respondsToSelector:@selector(isPassthrough)] && self.delegate.isPassthrough;
}

#pragma mark - Exported JS Functions

// clang-format off
RCT_EXPORT_METHOD(multiGet:(NSArray<NSString *> *)keys
                  callback:(RCTResponseSenderBlock)callback)
// clang-format on
{
    if (self.delegate != nil) {
        [self.delegate
            valuesForKeys:keys
               completion:^(NSArray<id<NSObject>> *valuesOrErrors) {
                 [self _multiGet:keys
                        callback:callback
                          getter:^NSString *(NSUInteger i, NSString *key, NSDictionary **errorOut) {
                            id valueOrError = valuesOrErrors[i];
                            if ([valueOrError isKindOfClass:[NSError class]]) {
                                NSError *error = (NSError *)valueOrError;
                                NSDictionary *extraData = @{@"key": RCTNullIfNil(key)};
                                *errorOut =
                                    RCTMakeError(error.localizedDescription, error, extraData);
                                return nil;
                            } else {
                                return [valueOrError isKindOfClass:[NSString class]]
                                           ? (NSString *)valueOrError
                                           : nil;
                            }
                          }];
               }];

        if (![self _passthroughDelegate]) {
            return;
        }
    }

    NSDictionary *ensureSetupErrorOut = [self _ensureSetup];
    if (ensureSetupErrorOut) {
        callback(@[@[ensureSetupErrorOut], (id)kCFNull]);
        return;
    }
    [self _multiGet:keys
           callback:callback
             getter:^(__unused NSUInteger i, NSString *key, NSDictionary **errorOut) {
               return [self _getValueForKey:key errorOut:errorOut];
             }];
}

// clang-format off
RCT_EXPORT_METHOD(multiSet:(NSArray<NSArray<NSString *> *> *)kvPairs
                  callback:(RCTResponseSenderBlock)callback)
// clang-format on
{
    if (self.delegate != nil) {
        NSMutableArray<NSString *> *keys = [NSMutableArray arrayWithCapacity:kvPairs.count];
        NSMutableArray<NSString *> *values = [NSMutableArray arrayWithCapacity:kvPairs.count];
        for (NSArray<NSString *> *entry in kvPairs) {
            [keys addObject:entry[0]];
            [values addObject:entry[1]];
        }
        [self.delegate setValues:values
                         forKeys:keys
                      completion:^(NSArray<id<NSObject>> *results) {
                        NSArray<NSDictionary *> *errors = RCTMakeErrors(results);
                        callback(@[RCTNullIfNil(errors)]);
                      }];

        if (![self _passthroughDelegate]) {
            return;
        }
    }

    NSDictionary *errorOut = [self _ensureSetup];
    if (errorOut) {
        callback(@[@[errorOut]]);
        return;
    }
    BOOL changedManifest = NO;
    NSMutableArray<NSDictionary *> *errors;
    for (NSArray<NSString *> *entry in kvPairs) {
        NSDictionary *keyError = [self _writeEntry:entry changedManifest:&changedManifest];
        RCTAppendError(keyError, &errors);
    }
    if (changedManifest) {
        [self _writeManifest:&errors];
    }
    callback(@[RCTNullIfNil(errors)]);
}

// clang-format off
RCT_EXPORT_METHOD(multiMerge:(NSArray<NSArray<NSString *> *> *)kvPairs
                    callback:(RCTResponseSenderBlock)callback)
// clang-format on
{
    if (self.delegate != nil) {
        NSMutableArray<NSString *> *keys = [NSMutableArray arrayWithCapacity:kvPairs.count];
        NSMutableArray<NSString *> *values = [NSMutableArray arrayWithCapacity:kvPairs.count];
        for (NSArray<NSString *> *entry in kvPairs) {
            [keys addObject:entry[0]];
            [values addObject:entry[1]];
        }
        [self.delegate mergeValues:values
                           forKeys:keys
                        completion:^(NSArray<id<NSObject>> *results) {
                          NSArray<NSDictionary *> *errors = RCTMakeErrors(results);
                          callback(@[RCTNullIfNil(errors)]);
                        }];

        if (![self _passthroughDelegate]) {
            return;
        }
    }

    NSDictionary *errorOut = [self _ensureSetup];
    if (errorOut) {
        callback(@[@[errorOut]]);
        return;
    }
    BOOL changedManifest = NO;
    NSMutableArray<NSDictionary *> *errors;
    for (__strong NSArray<NSString *> *entry in kvPairs) {
        NSDictionary *keyError;
        NSString *value = [self _getValueForKey:entry[0] errorOut:&keyError];
        if (!keyError) {
            if (value) {
                NSError *jsonError;
                NSMutableDictionary *mergedVal = RCTJSONParseMutable(value, &jsonError);
                NSDictionary *mergingValue = RCTJSONParse(entry[1], &jsonError);
                if (!mergingValue.count || RCTMergeRecursive(mergedVal, mergingValue)) {
                    entry = @[entry[0], RCTNullIfNil(RCTJSONStringify(mergedVal, NULL))];
                }
                if (jsonError) {
                    keyError = RCTJSErrorFromNSError(jsonError);
                }
            }
            if (!keyError) {
                keyError = [self _writeEntry:entry changedManifest:&changedManifest];
            }
        }
        RCTAppendError(keyError, &errors);
    }
    if (changedManifest) {
        [self _writeManifest:&errors];
    }
    callback(@[RCTNullIfNil(errors)]);
}

// clang-format off
RCT_EXPORT_METHOD(multiRemove:(NSArray<NSString *> *)keys
                     callback:(RCTResponseSenderBlock)callback)
// clang-format on
{
    if (self.delegate != nil) {
        [self.delegate removeValuesForKeys:keys
                                completion:^(NSArray<id<NSObject>> *results) {
                                  NSArray<NSDictionary *> *errors = RCTMakeErrors(results);
                                  callback(@[RCTNullIfNil(errors)]);
                                }];

        if (![self _passthroughDelegate]) {
            return;
        }
    }

    NSDictionary *errorOut = [self _ensureSetup];
    if (errorOut) {
        callback(@[@[errorOut]]);
        return;
    }
    NSMutableArray<NSDictionary *> *errors;
    BOOL changedManifest = NO;
    for (NSString *key in keys) {
        NSDictionary *keyError = RCTErrorForKey(key);
        if (!keyError) {
            if (_manifest[key] == (id)kCFNull) {
                NSString *filePath = [self _filePathForKey:key];
                [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                [RCTGetCache() removeObjectForKey:key];
            }
            if (_manifest[key]) {
                changedManifest = YES;
                [_manifest removeObjectForKey:key];
            }
        }
        RCTAppendError(keyError, &errors);
    }
    if (changedManifest) {
        [self _writeManifest:&errors];
    }
    callback(@[RCTNullIfNil(errors)]);
}

// clang-format off
RCT_EXPORT_METHOD(clear:(RCTResponseSenderBlock)callback)
// clang-format on
{
    if (self.delegate != nil) {
        [self.delegate removeAllValues:^(NSError *error) {
          NSDictionary *result = nil;
          if (error != nil) {
              result = RCTMakeError(error.localizedDescription, error, nil);
          }
          callback(@[RCTNullIfNil(result)]);
        }];
        return;
    }

    [_manifest removeAllObjects];
    [RCTGetCache() removeAllObjects];
    NSDictionary *error = RCTDeleteStorageDirectory();
    callback(@[RCTNullIfNil(error)]);
}

// clang-format off
RCT_EXPORT_METHOD(getAllKeys:(RCTResponseSenderBlock)callback)
// clang-format on
{
    if (self.delegate != nil) {
        [self.delegate allKeys:^(NSArray<id<NSObject>> *keys) {
          callback(@[(id)kCFNull, keys]);
        }];

        if (![self _passthroughDelegate]) {
            return;
        }
    }

    NSDictionary *errorOut = [self _ensureSetup];
    if (errorOut) {
        callback(@[errorOut, (id)kCFNull]);
    } else {
        callback(@[(id)kCFNull, _manifest.allKeys]);
    }
}

#pragma mark - RCTSandboxAwareModule

- (void)configureSandboxWithOrigin:(NSString *)origin
                     requestedName:(NSString *)requestedName
                      resolvedName:(NSString *)resolvedName
{
    if (!origin) {
        NSLog(@"[SandboxedRNCAsyncStorage] ERROR: origin is nil, refusing to configure");
        return;
    }
    NSString *appSupport = NSSearchPathForDirectoriesInDomains(
        NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"com.unknown";
    NSString *scopedDir = [[[[appSupport stringByAppendingPathComponent:bundleId]
        stringByAppendingPathComponent:@"Sandboxes"]
        stringByAppendingPathComponent:origin]
        stringByAppendingPathComponent:@"AsyncStorage"];

    NSLog(@"[SandboxedRNCAsyncStorage] Configuring for origin '%@', storage dir: %@", origin, scopedDir);
    self.storageDirectory = scopedDir;
    _configured = YES;
}

#if RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeAsyncStorageModuleSpecJSI>(params);
}
#endif

@end
