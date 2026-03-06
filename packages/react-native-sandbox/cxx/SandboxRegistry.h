#pragma once

#include <map>
#include <memory>
#include <mutex>
#include <set>
#include <string>
#include <vector>
#include "ISandboxDelegate.h"

namespace rnsandbox {

class SandboxRegistry {
 public:
  static SandboxRegistry& getInstance();

  void registerSandbox(
      const std::string& origin,
      std::shared_ptr<ISandboxDelegate> delegate,
      const std::set<std::string>& allowedOrigins);

  void unregisterDelegate(
      const std::string& origin,
      const std::shared_ptr<ISandboxDelegate>& delegate);

  void unregister(const std::string& origin);

  std::shared_ptr<ISandboxDelegate> find(const std::string& origin);

  std::vector<std::shared_ptr<ISandboxDelegate>> findAll(
      const std::string& origin);

  bool isPermittedFrom(
      const std::string& sourceOrigin,
      const std::string& targetOrigin);

  void reset();

 private:
  SandboxRegistry() = default;
  SandboxRegistry(const SandboxRegistry&) = delete;
  SandboxRegistry& operator=(const SandboxRegistry&) = delete;

  std::map<std::string, std::vector<std::shared_ptr<ISandboxDelegate>>>
      sandboxRegistry_;
  std::map<std::string, std::set<std::string>> allowedOrigins_;
  mutable std::recursive_mutex registryMutex_;
};

} // namespace rnsandbox
