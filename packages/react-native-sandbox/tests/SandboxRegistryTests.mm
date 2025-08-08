

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "../ios/SandboxRegistry.h"

@interface MockSandboxDelegate : NSObject
@property (nonatomic, copy, nullable) NSString *sandboxId;
@property (nonatomic, copy, nullable) NSString *lastMessage;
- (void)postMessage:(NSString *)message;
@end

@implementation MockSandboxDelegate

- (void)postMessage:(NSString *)message
{
  self.lastMessage = [message copy];
}

@end

@interface SandboxRegistryTests : XCTestCase
@end

@implementation SandboxRegistryTests

- (void)setUp
{
  [super setUp];

  // Clean up test sandboxes
  NSArray *testSandboxes = @[
    @"test-sandbox-1",
    @"test-sandbox-2",
    @"test-sandbox-3",
    @"sandbox1",
    @"sandbox2",
    @"sandbox3",
    @"concurrent1",
    @"concurrent2"
  ];

  for (NSString *sandboxId in testSandboxes) {
    [[SandboxRegistry shared] unregister:sandboxId];
  }
}

- (void)tearDown
{
  [super tearDown];

  // Clean up test sandboxes
  NSArray *testSandboxes = @[
    @"test-sandbox-1",
    @"test-sandbox-2",
    @"test-sandbox-3",
    @"sandbox1",
    @"sandbox2",
    @"sandbox3",
    @"concurrent1",
    @"concurrent2"
  ];

  for (NSString *sandboxId in testSandboxes) {
    [[SandboxRegistry shared] unregister:sandboxId];
  }
}

- (void)testRegisterAndGetSandbox
{
  MockSandboxDelegate *delegate = [[MockSandboxDelegate alloc] init];
  delegate.sandboxId = @"test-sandbox-1";

  [[SandboxRegistry shared] registerSandbox:@"test-sandbox-1" delegate:delegate allowedOrigins:nil];

  MockSandboxDelegate *retrieved = [[SandboxRegistry shared] find:@"test-sandbox-1"];

  XCTAssertEqual(delegate, retrieved, @"Retrieved delegate should be the same instance");
}

- (void)testUnregisterSandbox
{
  MockSandboxDelegate *delegate = [[MockSandboxDelegate alloc] init];
  [[SandboxRegistry shared] registerSandbox:@"test-sandbox-1" delegate:delegate allowedOrigins:nil];

  XCTAssertNotNil([[SandboxRegistry shared] find:@"test-sandbox-1"]);

  [[SandboxRegistry shared] unregister:@"test-sandbox-1"];

  XCTAssertNil([[SandboxRegistry shared] find:@"test-sandbox-1"]);
}

- (void)testRouteMessage
{
  MockSandboxDelegate *delegate1 = [[MockSandboxDelegate alloc] init];
  MockSandboxDelegate *delegate2 = [[MockSandboxDelegate alloc] init];

  [[SandboxRegistry shared] registerSandbox:@"test-sandbox-1" delegate:delegate1 allowedOrigins:nil];
  [[SandboxRegistry shared] registerSandbox:@"test-sandbox-2" delegate:delegate2 allowedOrigins:nil];

  // Test direct message routing using registry
  id target = [[SandboxRegistry shared] find:@"test-sandbox-2"];
  XCTAssertNotNil(target, @"Should retrieve delegate from registry");

  if ([target respondsToSelector:@selector(postMessage:)]) {
    [target postMessage:@"test message"];
    XCTAssertEqualObjects(delegate2.lastMessage, @"test message", @"Message should be received");
  }

  id nonExistent = [[SandboxRegistry shared] find:@"non-existent"];
  XCTAssertNil(nonExistent, @"Should return nil for non-existent sandbox");
}

- (void)testRegistrySeparation
{
  MockSandboxDelegate *delegate = [[MockSandboxDelegate alloc] init];

  [[SandboxRegistry shared] registerSandbox:@"test-sandbox-3" delegate:delegate allowedOrigins:nil];
  MockSandboxDelegate *retrieved = [[SandboxRegistry shared] find:@"test-sandbox-3"];

  XCTAssertEqual(delegate, retrieved, @"Registry should work independently of delegate");
}

- (void)testConcurrentAccess
{
  MockSandboxDelegate *delegate1 = [[MockSandboxDelegate alloc] init];
  MockSandboxDelegate *delegate2 = [[MockSandboxDelegate alloc] init];

  dispatch_group_t group = dispatch_group_create();

  dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [[SandboxRegistry shared] registerSandbox:@"concurrent-sandbox-1" delegate:delegate1 allowedOrigins:nil];
  });

  dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [[SandboxRegistry shared] registerSandbox:@"concurrent-sandbox-2" delegate:delegate2 allowedOrigins:nil];
  });

  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

  XCTAssertNotNil([[SandboxRegistry shared] find:@"concurrent-sandbox-1"]);
  XCTAssertNotNil([[SandboxRegistry shared] find:@"concurrent-sandbox-2"]);
}

- (void)testAllowedOrigins
{
  MockSandboxDelegate *delegate1 = [[MockSandboxDelegate alloc] init];
  MockSandboxDelegate *delegate2 = [[MockSandboxDelegate alloc] init];

  // Register sandbox1 with sandbox2 as allowed origin
  [[SandboxRegistry shared] registerSandbox:@"sandbox1" delegate:delegate1 allowedOrigins:@[ @"sandbox2" ]];

  // Register sandbox2 with no allowed origins
  [[SandboxRegistry shared] registerSandbox:@"sandbox2" delegate:delegate2 allowedOrigins:nil];

  // Test unidirectional permission
  XCTAssertTrue(
      [[SandboxRegistry shared] isPermittedFrom:@"sandbox1" to:@"sandbox2"],
      @"sandbox1 should be permitted to send messages to sandbox2");
  XCTAssertFalse(
      [[SandboxRegistry shared] isPermittedFrom:@"sandbox2" to:@"sandbox1"],
      @"sandbox2 should not be permitted to send messages to sandbox1");
}

- (void)testAllowedOriginsReregistration
{
  MockSandboxDelegate *delegate = [[MockSandboxDelegate alloc] init];

  // Initial registration with one allowed origin
  [[SandboxRegistry shared] registerSandbox:@"sandbox1" delegate:delegate allowedOrigins:@[ @"sandbox2" ]];
  XCTAssertTrue([[SandboxRegistry shared] isPermittedFrom:@"sandbox1" to:@"sandbox2"]);

  // Re-register with different allowed origins
  [[SandboxRegistry shared] registerSandbox:@"sandbox1" delegate:delegate allowedOrigins:@[ @"sandbox3" ]];

  // Old permission should be removed
  XCTAssertFalse(
      [[SandboxRegistry shared] isPermittedFrom:@"sandbox1" to:@"sandbox2"],
      @"Previous allowed origin should be removed after re-registration");

  // New permission should be granted
  XCTAssertTrue(
      [[SandboxRegistry shared] isPermittedFrom:@"sandbox1" to:@"sandbox3"],
      @"New allowed origin should be granted after re-registration");
}

- (void)testAllowedOriginsEdgeCases
{
  MockSandboxDelegate *delegate = [[MockSandboxDelegate alloc] init];

  // Test with empty array (explicit no permissions)
  [[SandboxRegistry shared] registerSandbox:@"sandbox1" delegate:delegate allowedOrigins:@[]];
  XCTAssertFalse(
      [[SandboxRegistry shared] isPermittedFrom:@"sandbox2" to:@"sandbox1"],
      @"Empty allowed origins array should deny all permissions");

  // Test with nil (implicit no permissions)
  [[SandboxRegistry shared] registerSandbox:@"sandbox2" delegate:delegate allowedOrigins:nil];
  XCTAssertFalse(
      [[SandboxRegistry shared] isPermittedFrom:@"sandbox1" to:@"sandbox2"],
      @"Nil allowed origins should deny all permissions");

  // Test with non-existent sandboxes
  XCTAssertFalse(
      [[SandboxRegistry shared] isPermittedFrom:@"non-existent1" to:@"non-existent2"],
      @"Non-existent sandboxes should return false");

  // Test self-messaging permission
  [[SandboxRegistry shared] registerSandbox:@"sandbox3" delegate:delegate allowedOrigins:@[ @"sandbox3" ]];
  XCTAssertTrue(
      [[SandboxRegistry shared] isPermittedFrom:@"sandbox3" to:@"sandbox3"],
      @"Self-messaging should be allowed if explicitly set");
}

- (void)testAllowedOriginsConcurrency
{
  MockSandboxDelegate *delegate = [[MockSandboxDelegate alloc] init];
  dispatch_group_t group = dispatch_group_create();

  // Concurrent registration and permission checks
  dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [[SandboxRegistry shared] registerSandbox:@"concurrent1" delegate:delegate allowedOrigins:@[ @"concurrent2" ]];
  });

  dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [[SandboxRegistry shared] registerSandbox:@"concurrent2" delegate:delegate allowedOrigins:@[ @"concurrent1" ]];
  });

  dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    (void)[[SandboxRegistry shared] isPermittedFrom:@"concurrent1" to:@"concurrent2"];
  });

  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

  // Verify final state after concurrent operations
  XCTAssertTrue(
      [[SandboxRegistry shared] isPermittedFrom:@"concurrent2" to:@"concurrent1"],
      @"Permissions should be properly set after concurrent operations");
  XCTAssertTrue(
      [[SandboxRegistry shared] isPermittedFrom:@"concurrent1" to:@"concurrent2"],
      @"Permissions should be properly set after concurrent operations");
}

@end