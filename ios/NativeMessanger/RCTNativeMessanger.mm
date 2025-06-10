//
//  RCTNativeMessanger.m
//  MultiInstancePOC
//
//  Created by Mike Grabowski on 06/06/2025.
//

#import "RCTNativeMessanger.h"

// Notification name for message passing
static NSString *const kMessageNotificationName = @"NativeMessangerMessageNotification";

@interface RCTNativeMessanger ()
@property (nonatomic, strong) NSMutableArray<RCTResponseSenderBlock> *messageCallbacks;
@end

@implementation RCTNativeMessanger

+ (NSString *)moduleName { 
  return @"NativeMessanger";
}

- (instancetype)init {
  if (self = [super init]) {
    _messageCallbacks = [NSMutableArray new];
    
    // Set up notification observer
    [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleMessageNotification:)
                                               name:kMessageNotificationName
                                             object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleMessageNotification:(NSNotification *)notification {
  NSDictionary *userInfo = notification.userInfo;
  NSString *receiver = userInfo[@"receiver"];
  NSString *message = userInfo[@"message"];
  
  UIView *view = RCTKeyWindow().rootViewController.view;
  
  if ([view isKindOfClass:[RCTSurfaceHostingProxyRootView class]]) {
    auto moduleName = ((RCTSurfaceHostingProxyRootView*)view).moduleName;
    NSLog(@"currentModuleName: %@", moduleName);
  }
  
  // Only process messages for our receiver
//  if ([receiver isEqualToString:@""]) {
    for (RCTResponseSenderBlock callback in self.messageCallbacks) {
      callback(@[message]);
    }
//  }
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeMessangerSpecJSI>(params);
}

- (void)sendMessage:(nonnull NSString *)message receiver:(nonnull NSString *)receiver { 
  NSDictionary *userInfo = @{
    @"message": message,
    @"receiver": receiver
  };
  
  // Post the notification
  [[NSNotificationCenter defaultCenter] postNotificationName:kMessageNotificationName
                                                    object:nil
                                                  userInfo:userInfo];
}

- (void)receiveMessage:(nonnull RCTResponseSenderBlock)callback {
  [self.messageCallbacks addObject:callback];
}

@end
