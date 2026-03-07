#include "SandboxRegistry.h"
#include <algorithm>
#include <iostream>

namespace rnsandbox {

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

  auto& delegates = sandboxRegistry_[origin];
  // Avoid duplicate registration of the same delegate
  for (const auto& d : delegates) {
    if (d == delegate) {
      return;
    }
  }
  delegates.push_back(delegate);
  allowedOrigins_[origin] = allowedOrigins;
}

void SandboxRegistry::unregisterDelegate(
    const std::string& origin,
    const std::shared_ptr<ISandboxDelegate>& delegate) {
  if (origin.empty() || !delegate) {
    return;
  }

  std::lock_guard<std::recursive_mutex> lock(registryMutex_);

  auto it = sandboxRegistry_.find(origin);
  if (it == sandboxRegistry_.end()) {
    return;
  }

  auto& delegates = it->second;
  delegates.erase(
      std::remove(delegates.begin(), delegates.end(), delegate),
      delegates.end());

  if (delegates.empty()) {
    sandboxRegistry_.erase(it);
    allowedOrigins_.erase(origin);
  }
}

void SandboxRegistry::unregister(const std::string& origin) {
  if (origin.empty()) {
    return;
  }

  std::lock_guard<std::recursive_mutex> lock(registryMutex_);
  sandboxRegistry_.erase(origin);
  allowedOrigins_.erase(origin);
}

std::shared_ptr<ISandboxDelegate> SandboxRegistry::find(
    const std::string& origin) {
  if (origin.empty()) {
    return nullptr;
  }

  std::lock_guard<std::recursive_mutex> lock(registryMutex_);

  auto it = sandboxRegistry_.find(origin);
  if (it != sandboxRegistry_.end() && !it->second.empty()) {
    return it->second.front();
  }

  return nullptr;
}

std::vector<std::shared_ptr<ISandboxDelegate>> SandboxRegistry::findAll(
    const std::string& origin) {
  if (origin.empty()) {
    return {};
  }

  std::lock_guard<std::recursive_mutex> lock(registryMutex_);

  auto it = sandboxRegistry_.find(origin);
  if (it != sandboxRegistry_.end()) {
    return it->second;
  }

  return {};
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

} // namespace rnsandbox
