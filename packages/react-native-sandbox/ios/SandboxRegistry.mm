//
//  SandboxRegistry.mm
//  react-native-sandbox
//
//  Created by Aliaksandr Babrykovich on 25/06/2025.
//

#import "SandboxRegistry.h"

#include <map>
#include <mutex>
#include <set>

@implementation SandboxRegistry

#pragma mark - Singleton Implementation

+ (instancetype)shared
{
  static SandboxRegistry *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

#pragma mark - Instance Registry Implementation

// Global static registry for sandbox communication
static std::map<std::string, id> _sandboxRegistry;
static std::map<std::string, std::set<std::string>> _allowedOrigins;
static std::recursive_mutex _registryMutex;

- (void)registerSandbox:(NSString *)sandboxOrigin
               delegate:(id)delegate
         allowedOrigins:(nullable NSArray<NSString *> *)allowedOrigins
{
  if (!sandboxOrigin || !delegate) {
    return;
  }

  std::lock_guard<std::recursive_mutex> lock(_registryMutex);
  std::string cppSandboxOrigin = [sandboxOrigin UTF8String];

  if (_sandboxRegistry.find(cppSandboxOrigin) != _sandboxRegistry.end()) {
    NSLog(@"[SandboxRegistry] Warning: Overwriting existing sandbox with origin: %@", sandboxOrigin);
  }

  _sandboxRegistry[cppSandboxOrigin] = delegate;

  // Clear existing allowed origins and set new ones
  _allowedOrigins[cppSandboxOrigin] = std::set<std::string>();

  if (allowedOrigins) {
    for (NSString *originId in allowedOrigins) {
      _allowedOrigins[cppSandboxOrigin].insert([originId UTF8String]);
    }
  }
}

- (void)unregister:(NSString *)sandboxOrigin
{
  if (!sandboxOrigin) {
    return;
  }

  std::lock_guard<std::recursive_mutex> lock(_registryMutex);
  std::string cppSandboxOrigin = [sandboxOrigin UTF8String];

  auto it = _sandboxRegistry.find(cppSandboxOrigin);
  if (it != _sandboxRegistry.end()) {
    _sandboxRegistry.erase(it);
  }

  auto originsIt = _allowedOrigins.find(cppSandboxOrigin);
  if (originsIt != _allowedOrigins.end()) {
    _allowedOrigins.erase(originsIt);
  }
}

- (nullable id)find:(NSString *)sandboxOrigin
{
  if (!sandboxOrigin) {
    return nil;
  }

  std::lock_guard<std::recursive_mutex> lock(_registryMutex);
  std::string cppSandboxOrigin = [sandboxOrigin UTF8String];

  auto it = _sandboxRegistry.find(cppSandboxOrigin);
  if (it != _sandboxRegistry.end()) {
    return it->second;
  }

  return nil;
}

- (BOOL)isPermittedFrom:(NSString *)sourceOrigin to:(NSString *)targetOrigin
{
  if (!sourceOrigin || !targetOrigin) {
    return NO;
  }

  std::lock_guard<std::recursive_mutex> lock(_registryMutex);
  std::string cppTargetOrigin = [targetOrigin UTF8String];
  std::string cppSourceOrigin = [sourceOrigin UTF8String];

  auto originsIt = _allowedOrigins.find(cppSourceOrigin);
  if (originsIt == _allowedOrigins.end()) {
    return NO;
  }

  return originsIt->second.find(cppTargetOrigin) != originsIt->second.end();
}

@end
