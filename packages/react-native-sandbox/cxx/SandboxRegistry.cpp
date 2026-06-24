#include "SandboxRegistry.h"
#include <algorithm>

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
  bool alreadyRegistered = false;
  for (const auto& d : delegates) {
    if (d == delegate) {
      alreadyRegistered = true;
      break;
    }
  }
  if (!alreadyRegistered) {
    delegates.push_back(delegate);
  }
  // Always update allowedOrigins (may change after initial registration)
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

  // Check the TARGET's allowedOrigins to see if the source is permitted
  // to send messages to it. This matches the documented semantics:
  // "allowedOrigins specifies which sandbox origins are allowed to send
  // messages TO this sandbox."
  auto originsIt = allowedOrigins_.find(targetOrigin);
  if (originsIt == allowedOrigins_.end()) {
    return false;
  }

  return originsIt->second.find(sourceOrigin) != originsIt->second.end();
}

void SandboxRegistry::reset() {
  std::lock_guard<std::recursive_mutex> lock(registryMutex_);
  sandboxRegistry_.clear();
  allowedOrigins_.clear();
}

void SandboxRegistry::updateAllowedOrigins(
    const std::string& origin,
    const std::set<std::string>& allowedOrigins) {
  if (origin.empty()) {
    return;
  }

  std::lock_guard<std::recursive_mutex> lock(registryMutex_);
  allowedOrigins_[origin] = allowedOrigins;
}

} // namespace rnsandbox
