#include <fmt/format.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>
#include <chrono>
#include <future>
#include <thread>
#include <vector>

#include <SandboxRegistry.h>

#include "MockSandboxDelegate.h"

using namespace facebook::react;
using ::testing::_;
using ::testing::Return;
using ::testing::StrictMock;

class SandboxRegistryTest : public ::testing::Test {
 protected:
  void SetUp() override {
    auto& registry = SandboxRegistry::getInstance();
    registry.reset();
  }
};

TEST_F(SandboxRegistryTest, RegisterAndFindSandbox) {
  auto& registry = SandboxRegistry::getInstance();
  auto mockDelegate = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> allowedOrigins = {"allowed1", "allowed2"};
  registry.registerSandbox("test-origin", mockDelegate, allowedOrigins);

  auto found = registry.find("test-origin");
  EXPECT_EQ(found, mockDelegate);

  auto notFound = registry.find("non-existent");
  EXPECT_EQ(notFound, nullptr);
}

TEST_F(SandboxRegistryTest, UnregisterSandbox) {
  auto& registry = SandboxRegistry::getInstance();
  auto mockDelegate = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> allowedOrigins = {"allowed1"};
  registry.registerSandbox("test-origin", mockDelegate, allowedOrigins);

  auto found = registry.find("test-origin");
  EXPECT_EQ(found, mockDelegate);

  registry.unregister("test-origin");

  auto notFound = registry.find("test-origin");
  EXPECT_EQ(notFound, nullptr);
}

TEST_F(SandboxRegistryTest, IsPermittedFrom) {
  auto& registry = SandboxRegistry::getInstance();
  auto mockDelegate1 = std::make_shared<StrictMock<MockSandboxDelegate>>();
  auto mockDelegate2 = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> allowedOrigins1 = {"sandbox2"};
  std::set<std::string> allowedOrigins2 = {"sandbox1"};

  registry.registerSandbox("sandbox1", mockDelegate1, allowedOrigins1);
  registry.registerSandbox("sandbox2", mockDelegate2, allowedOrigins2);

  EXPECT_TRUE(registry.isPermittedFrom("sandbox1", "sandbox2"));
  EXPECT_TRUE(registry.isPermittedFrom("sandbox2", "sandbox1"));

  EXPECT_FALSE(registry.isPermittedFrom("sandbox1", "sandbox3"));
  EXPECT_FALSE(registry.isPermittedFrom("sandbox3", "sandbox1"));
}

TEST_F(SandboxRegistryTest, EmptyAllowedOrigins) {
  auto& registry = SandboxRegistry::getInstance();
  auto mockDelegate = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> emptyOrigins;
  registry.registerSandbox("test-origin", mockDelegate, emptyOrigins);

  EXPECT_FALSE(registry.isPermittedFrom("any-origin", "test-origin"));
  EXPECT_FALSE(registry.isPermittedFrom("test-origin", "any-origin"));
}

TEST_F(SandboxRegistryTest, OverwriteExistingSandbox) {
  auto& registry = SandboxRegistry::getInstance();
  auto mockDelegate1 = std::make_shared<StrictMock<MockSandboxDelegate>>();
  auto mockDelegate2 = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> allowedOrigins1 = {"allowed1"};
  std::set<std::string> allowedOrigins2 = {"allowed2"};

  registry.registerSandbox("test-origin", mockDelegate1, allowedOrigins1);

  registry.registerSandbox("test-origin", mockDelegate2, allowedOrigins2);

  auto found = registry.find("test-origin");
  EXPECT_EQ(found, mockDelegate2);

  EXPECT_FALSE(registry.isPermittedFrom("allowed2", "test-origin"));
  EXPECT_FALSE(registry.isPermittedFrom("allowed1", "test-origin"));
}

TEST_F(SandboxRegistryTest, EmptyOriginHandling) {
  auto& registry = SandboxRegistry::getInstance();
  auto mockDelegate = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> allowedOrigins = {"allowed1"};

  registry.registerSandbox("", mockDelegate, allowedOrigins);

  auto found = registry.find("");
  EXPECT_EQ(found, nullptr);
}

TEST_F(SandboxRegistryTest, NullDelegateHandling) {
  auto& registry = SandboxRegistry::getInstance();

  std::set<std::string> allowedOrigins = {"allowed1"};

  registry.registerSandbox("test-origin", nullptr, allowedOrigins);

  auto found = registry.find("test-origin");
  EXPECT_EQ(found, nullptr);
}

TEST_F(SandboxRegistryTest, EdgeCases) {
  auto& registry = SandboxRegistry::getInstance();
  auto mockDelegate = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> emptyOrigins;
  registry.registerSandbox("", mockDelegate, emptyOrigins);
  EXPECT_EQ(registry.find(""), nullptr);

  registry.registerSandbox("test", nullptr, emptyOrigins);
  EXPECT_EQ(registry.find("test"), nullptr);

  registry.unregister("non-existent");
  EXPECT_EQ(registry.find("non-existent"), nullptr);

  EXPECT_FALSE(registry.isPermittedFrom("", "test"));
  EXPECT_FALSE(registry.isPermittedFrom("test", ""));
}

TEST_F(SandboxRegistryTest, ThreadSafety) {
  auto& registry = SandboxRegistry::getInstance();
  const int numThreads = 4;
  const int operationsPerThread = 100;

  std::vector<std::future<void>> futures;

  for (int threadId = 0; threadId < numThreads; ++threadId) {
    futures.emplace_back(
        std::async(std::launch::async, [&registry, threadId]() {
          for (int i = 0; i < operationsPerThread; ++i) {
            auto mockDelegate =
                std::make_shared<StrictMock<MockSandboxDelegate>>();
            std::string origin =
                "sandbox_" + std::to_string(threadId) + "_" + std::to_string(i);
            std::set<std::string> allowedOrigins = {"other_sandbox"};

            registry.registerSandbox(origin, mockDelegate, allowedOrigins);

            auto found = registry.find(origin);
            EXPECT_EQ(found, mockDelegate);

            EXPECT_TRUE(registry.isPermittedFrom(origin, "other_sandbox"));
            EXPECT_FALSE(registry.isPermittedFrom(origin, "blocked_sandbox"));

            registry.unregister(origin);

            auto notFound = registry.find(origin);
            EXPECT_EQ(notFound, nullptr);
          }
        }));
  }

  for (auto& future : futures) {
    auto status = future.wait_for(std::chrono::seconds(5));
    EXPECT_EQ(status, std::future_status::ready)
        << "Thread safety test timed out after 5 seconds";
  }
}