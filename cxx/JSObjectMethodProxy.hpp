//
//  JSObjectMethodProxy.hpp
//  MultiInstancePOC
//
//  Created by Aliaksandr Babrykovich on 28/06/2025.
//

#pragma once

#include <jsi/jsi.h>
#include <functional>
#include <string>

namespace fjsi = facebook::jsi;

class JSObjectMethodProxy final {
public:
  using Condition = std::function<bool(
    const fjsi::Runtime&,
    const fjsi::Value*,
    size_t)>;

  JSObjectMethodProxy(
    fjsi::Runtime& runtime,
    fjsi::Object& object,
    const std::string& methodName,
    const std::size_t count,
    Condition condition);

  ~JSObjectMethodProxy();

private:
  fjsi::Runtime& runtime_;
  fjsi::Object& object_;
  std::string methodName_;
  fjsi::Function original_;
};
