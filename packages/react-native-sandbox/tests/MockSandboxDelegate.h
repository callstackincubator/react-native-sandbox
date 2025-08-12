#pragma once

#include <gmock/gmock.h>
#include <string>
#include <vector>

#include <ISandboxDelegate.h>

namespace facebook {
namespace react {

class MockSandboxDelegate : public ISandboxDelegate {
 public:
  MOCK_METHOD(void, postMessage, (const std::string& message), (override));
  MOCK_METHOD(
      bool,
      routeMessage,
      (const std::string& message, const std::string& targetId),
      (override));
  MOCK_METHOD(void, setOrigin, (const std::string& origin), (override));
  MOCK_METHOD(
      void,
      setAllowedOrigins,
      (const std::set<std::string>& origins),
      (override));
  MOCK_METHOD(
      void,
      setAllowedTurboModules,
      (const std::set<std::string>& modules),
      (override));
};

} // namespace react
} // namespace facebook