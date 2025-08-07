

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

  [[SandboxRegistry shared] unregister:@"test-sandbox-1"];
  [[SandboxRegistry shared] unregister:@"test-sandbox-2"];
  [[SandboxRegistry shared] unregister:@"test-sandbox-3"];
}

- (void)tearDown
{
  [super tearDown];

  [[SandboxRegistry shared] unregister:@"test-sandbox-1"];
  [[SandboxRegistry shared] unregister:@"test-sandbox-2"];
  [[SandboxRegistry shared] unregister:@"test-sandbox-3"];
}

- (void)testRegisterAndGetSandbox
{
  MockSandboxDelegate *delegate = [[MockSandboxDelegate alloc] init];
  delegate.sandboxId = @"test-sandbox-1";

  [[SandboxRegistry shared] register:@"test-sandbox-1" delegate:delegate];

  MockSandboxDelegate *retrieved = [[SandboxRegistry shared] find:@"test-sandbox-1"];

  XCTAssertEqual(delegate, retrieved, @"Retrieved delegate should be the same instance");
}

- (void)testUnregisterSandbox
{
  MockSandboxDelegate *delegate = [[MockSandboxDelegate alloc] init];
  [[SandboxRegistry shared] register:@"test-sandbox-1" delegate:delegate];

  XCTAssertNotNil([[SandboxRegistry shared] find:@"test-sandbox-1"]);

  [[SandboxRegistry shared] unregister:@"test-sandbox-1"];

  XCTAssertNil([[SandboxRegistry shared] find:@"test-sandbox-1"]);
}

- (void)testRouteMessage
{
  MockSandboxDelegate *delegate1 = [[MockSandboxDelegate alloc] init];
  MockSandboxDelegate *delegate2 = [[MockSandboxDelegate alloc] init];

  [[SandboxRegistry shared] register:@"test-sandbox-1" delegate:delegate1];
  [[SandboxRegistry shared] register:@"test-sandbox-2" delegate:delegate2];

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

  [[SandboxRegistry shared] register:@"test-sandbox-3" delegate:delegate];
  MockSandboxDelegate *retrieved = [[SandboxRegistry shared] find:@"test-sandbox-3"];

  XCTAssertEqual(delegate, retrieved, @"Registry should work independently of delegate");
}

- (void)testConcurrentAccess
{
  MockSandboxDelegate *delegate1 = [[MockSandboxDelegate alloc] init];
  MockSandboxDelegate *delegate2 = [[MockSandboxDelegate alloc] init];

  dispatch_group_t group = dispatch_group_create();

  dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [[SandboxRegistry shared] register:@"concurrent-sandbox-1" delegate:delegate1];
  });

  dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [[SandboxRegistry shared] register:@"concurrent-sandbox-2" delegate:delegate2];
  });

  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

  XCTAssertNotNil([[SandboxRegistry shared] find:@"concurrent-sandbox-1"]);
  XCTAssertNotNil([[SandboxRegistry shared] find:@"concurrent-sandbox-2"]);
}

@end