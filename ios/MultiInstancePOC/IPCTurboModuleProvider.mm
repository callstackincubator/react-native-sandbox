//
//  IPCTurboModuleProvider.mm
//  MultiInstancePOC
//
//  Created by Aliaksandr Babrykovich on 10/06/2025.
//

#import "IPCTurboModuleProvider.h"

#import <ReactCommon/CallInvoker.h>
#import <ReactCommon/TurboModule.h>

#import "IPCTurboModule.hpp"

@implementation IPCTurboModuleProvider

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::IPCTurboModule>(params.jsInvoker);
}

@end
