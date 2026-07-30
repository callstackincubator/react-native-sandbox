// Copyright 2025-present Callstack. All rights reserved.

#import "SandboxExpoFactory.h"

// Expo runtime wiring — mirrors EXReactNativeFactory's host:didInitializeRuntime: body
// exactly, except the AppContext is created via SandboxAppContextBridge (scoped dirs).
#import <ExpoModulesCore/EXHostWrapper.h>
#if __has_include(<ExpoModulesCore/ExpoModulesCore-Swift.h>)
#import <ExpoModulesCore/ExpoModulesCore-Swift.h>
#elif __has_include("ExpoModulesCore-Swift.h")
#import "ExpoModulesCore-Swift.h"
#endif
#import <ReactCommon/RCTHost.h>
#import <react/renderer/runtimescheduler/RuntimeSchedulerBinding.h>
#import <ExpoModulesCore/EXReactSchedulerDispatch.h>

// Generated ObjC bridge for SandboxAppContextBridge.swift
#import "React_Sandbox-Swift.h"

@implementation SandboxExpoFactory {
  EXAppContext *_appContext;
  NSString *_origin;
}

- (instancetype)initWithDelegate:(id<RCTReactNativeFactoryDelegate>)delegate
                          origin:(nullable NSString *)origin
{
  if (self = [super initWithDelegate:delegate]) {
    _origin = [origin copy];
  }
  return self;
}

// [JS thread] Mirrors EXReactNativeFactory's implementation verbatim, except
// the AppContext is created with origin-scoped document/cache directories.
- (void)host:(nonnull RCTHost *)host didInitializeRuntime:(facebook::jsi::Runtime &)runtime
{
  _appContext = [SandboxAppContextBridge createScopedAppContextForOrigin:_origin ?: @""];

  auto binding = facebook::react::RuntimeSchedulerBinding::getBinding(runtime);
  auto scheduler = binding ? binding->getRuntimeScheduler() : nullptr;
  void *schedulerHandle = expo::createReactSchedulerHandle(scheduler);

  [_appContext setRuntime:&runtime
                scheduler:schedulerHandle
                 dispatch:schedulerHandle ? reinterpret_cast<const void *>(&expo::dispatchOnReactScheduler) : nullptr];
  [_appContext setHostWrapper:[[EXHostWrapper alloc] initWithHost:host]];
  [_appContext registerNativeModules];
}

@end
