#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

int main([[maybe_unused]] int argc, [[maybe_unused]] const char *argv[])
{
  int totalTests = 0;
  int passedTests = 0;
  int failedTests = 0;

  @autoreleasepool {
    NSArray<NSString *> *testCaseNames = @[
      @"SandboxRegistryTests",
    ];

    for (NSString *testCaseName in testCaseNames) {
      XCTestSuite *testSuite = [XCTestSuite testSuiteForTestCaseWithName:testCaseName];

      for (XCTest *test in testSuite.tests) {
        totalTests++;

        XCTestRun *testRun = [[XCTestRun alloc] initWithTest:test];
        [test performTest:testRun];

        if (testRun.totalFailureCount == 0) {
          passedTests++;
          NSLog(@"✅ %@ - PASSED", test.name);
        } else {
          failedTests++;
          NSLog(@"❌ %@ - FAILED", test.name);
        }
      }
    }
  }

  NSLog(@"🧪 SandboxRegistry Tests Summary:");
  NSLog(@"   Tests run: %d", totalTests);
  NSLog(@"   Tests passed: %d", passedTests);
  NSLog(@"   Tests failed: %d", failedTests);

  return failedTests == 0 ? 0 : 1;
}