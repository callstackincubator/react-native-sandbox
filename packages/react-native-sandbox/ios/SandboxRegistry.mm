//
//  SandboxRegistry.mm
//  react-native-sandbox
//
//  Created by Aliaksandr Babrykovich on 25/06/2025.
//

#import "SandboxRegistry.h"

#include <map>
#include <mutex>

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
static std::recursive_mutex _registryMutex;

- (void)register:(NSString *)sandboxId delegate:(id)delegate
{
  if (!sandboxId || !delegate) {
    return;
  }

  std::lock_guard<std::recursive_mutex> lock(_registryMutex);
  std::string cppSandboxId = [sandboxId UTF8String];

  if (_sandboxRegistry.find(cppSandboxId) != _sandboxRegistry.end()) {
    NSLog(@"[SandboxRegistry] Warning: Overwriting existing sandbox with ID: %@", sandboxId);
  }

  _sandboxRegistry[cppSandboxId] = delegate;
}

- (void)unregister:(NSString *)sandboxId
{
  if (!sandboxId) {
    return;
  }

  std::lock_guard<std::recursive_mutex> lock(_registryMutex);
  std::string cppSandboxId = [sandboxId UTF8String];

  auto it = _sandboxRegistry.find(cppSandboxId);
  if (it != _sandboxRegistry.end()) {
    _sandboxRegistry.erase(it);
  }
}

- (nullable id)find:(NSString *)sandboxId
{
  if (!sandboxId) {
    return nil;
  }

  std::lock_guard<std::recursive_mutex> lock(_registryMutex);
  std::string cppSandboxId = [sandboxId UTF8String];

  auto it = _sandboxRegistry.find(cppSandboxId);
  if (it != _sandboxRegistry.end()) {
    return it->second;
  }

  return nil;
}

@end