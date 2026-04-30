#include <gmock/gmock.h>
#include <gtest/gtest.h>
#include <chrono>
#include <future>
#include <thread>
#include <vector>

#include <SandboxRegistry.h>

#include "MockSandboxDelegate.h"

using namespace rnsandbox;
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

TEST_F(SandboxRegistryTest, MultipleDelegatesSameOrigin) {
  auto& registry = SandboxRegistry::getInstance();
  auto delegate1 = std::make_shared<StrictMock<MockSandboxDelegate>>();
  auto delegate2 = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> allowedOrigins = {"other"};
  registry.registerSandbox("shared", delegate1, allowedOrigins);
  registry.registerSandbox("shared", delegate2, allowedOrigins);

  // find returns the first
  EXPECT_EQ(registry.find("shared"), delegate1);

  // findAll returns both
  auto all = registry.findAll("shared");
  EXPECT_EQ(all.size(), 2u);
  EXPECT_EQ(all[0], delegate1);
  EXPECT_EQ(all[1], delegate2);
}

TEST_F(SandboxRegistryTest, UnregisterDelegateRemovesOnlyThatDelegate) {
  auto& registry = SandboxRegistry::getInstance();
  auto delegate1 = std::make_shared<StrictMock<MockSandboxDelegate>>();
  auto delegate2 = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> allowedOrigins = {"other"};
  registry.registerSandbox("shared", delegate1, allowedOrigins);
  registry.registerSandbox("shared", delegate2, allowedOrigins);

  registry.unregisterDelegate("shared", delegate1);

  auto all = registry.findAll("shared");
  EXPECT_EQ(all.size(), 1u);
  EXPECT_EQ(all[0], delegate2);
  EXPECT_EQ(registry.find("shared"), delegate2);
}

TEST_F(SandboxRegistryTest, UnregisterDelegateLastCleansUpOrigin) {
  auto& registry = SandboxRegistry::getInstance();
  auto delegate = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> allowedOrigins = {"other"};
  registry.registerSandbox("solo", delegate, allowedOrigins);

  registry.unregisterDelegate("solo", delegate);

  EXPECT_EQ(registry.find("solo"), nullptr);
  EXPECT_TRUE(registry.findAll("solo").empty());
  EXPECT_FALSE(registry.isPermittedFrom("solo", "other"));
}

TEST_F(SandboxRegistryTest, DuplicateRegistrationIgnored) {
  auto& registry = SandboxRegistry::getInstance();
  auto delegate = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> allowedOrigins;
  registry.registerSandbox("dup", delegate, allowedOrigins);
  registry.registerSandbox("dup", delegate, allowedOrigins);

  auto all = registry.findAll("dup");
  EXPECT_EQ(all.size(), 1u);
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

TEST_F(SandboxRegistryTest, AllowedOriginsOverwriteOnReRegistration) {
  auto& registry = SandboxRegistry::getInstance();
  auto delegate1 = std::make_shared<StrictMock<MockSandboxDelegate>>();
  auto delegate2 = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> firstOrigins = {"allowed-a"};
  registry.registerSandbox("shared-origin", delegate1, firstOrigins);
  EXPECT_TRUE(registry.isPermittedFrom("shared-origin", "allowed-a"));
  EXPECT_FALSE(registry.isPermittedFrom("shared-origin", "allowed-b"));

  std::set<std::string> secondOrigins = {"allowed-b"};
  registry.registerSandbox("shared-origin", delegate2, secondOrigins);

  // Second registration overwrites the allowedOrigins for the whole origin
  EXPECT_FALSE(registry.isPermittedFrom("shared-origin", "allowed-a"));
  EXPECT_TRUE(registry.isPermittedFrom("shared-origin", "allowed-b"));

  // Both delegates are still registered
  auto all = registry.findAll("shared-origin");
  EXPECT_EQ(all.size(), 2u);
}

TEST_F(SandboxRegistryTest, UnregisterDelegateWithUnknownDelegateIsNoOp) {
  auto& registry = SandboxRegistry::getInstance();
  auto registered = std::make_shared<StrictMock<MockSandboxDelegate>>();
  auto unknown = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> allowedOrigins = {"other"};
  registry.registerSandbox("origin", registered, allowedOrigins);

  // Unregistering a delegate that was never registered should be a no-op
  registry.unregisterDelegate("origin", unknown);

  auto all = registry.findAll("origin");
  EXPECT_EQ(all.size(), 1u);
  EXPECT_EQ(all[0], registered);

  // Unregistering from a non-existent origin should also be a no-op
  registry.unregisterDelegate("nonexistent", registered);
}

TEST_F(SandboxRegistryTest, FindAllWithNonExistentOrigin) {
  auto& registry = SandboxRegistry::getInstance();

  auto result = registry.findAll("never-registered");
  EXPECT_TRUE(result.empty());
}

TEST_F(SandboxRegistryTest, ResetReleasesSharedPtrReferences) {
  auto& registry = SandboxRegistry::getInstance();
  auto delegate = std::make_shared<StrictMock<MockSandboxDelegate>>();

  std::set<std::string> allowedOrigins = {"other"};
  registry.registerSandbox("origin-a", delegate, allowedOrigins);

  // Registry holds a reference, so use_count should be > 1
  EXPECT_GT(delegate.use_count(), 1);

  registry.reset();

  // After reset, the registry should have released its reference
  EXPECT_EQ(delegate.use_count(), 1);

  // Registry should be empty
  EXPECT_EQ(registry.find("origin-a"), nullptr);
  EXPECT_TRUE(registry.findAll("origin-a").empty());
  EXPECT_FALSE(registry.isPermittedFrom("origin-a", "other"));
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

            registry.unregisterDelegate(origin, mockDelegate);

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
