#pragma once

#include <React/RCTComponentViewDescriptor.h>
#include <react/renderer/core/ConcreteComponentDescriptor.h>
#include "RNMultInstanceSpec.h"

namespace facebook {
namespace react {

/*
 * Descriptor for SandboxReactNativeView component.
 */
class SandboxReactNativeViewComponentDescriptor final
    : public ConcreteComponentDescriptor<SandboxReactNativeViewShadowNode> {
 public:
  SandboxReactNativeViewComponentDescriptor(
      const ComponentDescriptorParameters& parameters)
      : ConcreteComponentDescriptor(parameters) {}
};

} // namespace react
} // namespace facebook