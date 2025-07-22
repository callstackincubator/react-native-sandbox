#pragma once

#include "RNMultInstanceSpec.h"
#include <React/RCTComponentViewDescriptor.h>
#include <react/renderer/core/ConcreteComponentDescriptor.h>

namespace facebook {
namespace react {

/*
 * Descriptor for SandboxReactNativeView component.
 */
class SandboxReactNativeViewComponentDescriptor final
    : public ConcreteComponentDescriptor<SandboxReactNativeViewShadowNode> {
public:
  SandboxReactNativeViewComponentDescriptor(ComponentDescriptorParameters const &parameters)
      : ConcreteComponentDescriptor(parameters) {}
};

} // namespace react
} // namespace facebook 