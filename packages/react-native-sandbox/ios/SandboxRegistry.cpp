#include "SandboxRegistry.h"
#include <fmt/format.h>
#include <iostream>

namespace facebook {
namespace react {

/**
 * Implementation of the thread-safe C++ SandboxRegistry.
 *
 * This class provides a singleton registry for managing sandbox delegates
 * across multiple React Native instances. It uses std::recursive_mutex for
 * thread safety and std::map for efficient lookups.
 *
 * Key features:
 * - Thread-safe operations with recursive mutex
 * - Efficient O(log n) lookups using std::map
 * - Automatic cleanup of unregistered sandboxes
 * - Support for permission-based communication
 */

SandboxRegistry& SandboxRegistry::getInstance() {
  static SandboxRegistry instance;
  return instance;
}

void SandboxRegistry::registerSandbox(
    const std::string& origin,
    std::shared_ptr<ISandboxDelegate> delegate,
    const std::set<std::string>& allowedOrigins) {
  if (origin.empty() || !delegate) {
    return;
  }

  std::lock_guard<std::recursive_mutex> lock(registryMutex_);

  if (sandboxRegistry_.find(origin) != sandboxRegistry_.end()) {
    std::cerr
        << fmt::format(
               "[SandboxRegistry] Warning: Overwriting existing sandbox with origin: {}",
               origin)
        << std::endl;
  }

  sandboxRegistry_[origin] = delegate;
  allowedOrigins_[origin] = allowedOrigins;
}

void SandboxRegistry::unregister(const std::string& origin) {
  if (origin.empty()) {
    return;
  }

  std::lock_guard<std::recursive_mutex> lock(registryMutex_);

  auto registryIt = sandboxRegistry_.find(origin);
  if (registryIt != sandboxRegistry_.end()) {
    sandboxRegistry_.erase(registryIt);
  }

  auto originsIt = allowedOrigins_.find(origin);
  if (originsIt != allowedOrigins_.end()) {
    allowedOrigins_.erase(originsIt);
  }
}

std::shared_ptr<ISandboxDelegate> SandboxRegistry::find(
    const std::string& origin) {
  if (origin.empty()) {
    return nullptr;
  }

  std::lock_guard<std::recursive_mutex> lock(registryMutex_);

  auto it = sandboxRegistry_.find(origin);
  if (it != sandboxRegistry_.end()) {
    return it->second;
  }

  return nullptr;
}

bool SandboxRegistry::isPermittedFrom(
    const std::string& sourceOrigin,
    const std::string& targetOrigin) {
  if (sourceOrigin.empty() || targetOrigin.empty()) {
    return false;
  }

  std::lock_guard<std::recursive_mutex> lock(registryMutex_);

  auto originsIt = allowedOrigins_.find(sourceOrigin);
  if (originsIt == allowedOrigins_.end()) {
    return false;
  }

  return originsIt->second.find(targetOrigin) != originsIt->second.end();
}

void SandboxRegistry::reset() {
  std::lock_guard<std::recursive_mutex> lock(registryMutex_);
  sandboxRegistry_.clear();
  allowedOrigins_.clear();
}

} // namespace react
} // namespace facebook