//
//  JSObjectMethodProxy.cpp
//  MultiInstancePOC
//
//  Created by Aliaksandr Babrykovich on 28/06/2025.
//

#include "JSObjectMethodProxy.hpp"

JSObjectMethodProxy::JSObjectMethodProxy(
    fjsi::Runtime& runtime,
    fjsi::Object& object,
    const std::string& methodName,
    const std::size_t count,
    Condition condition)
    : runtime_(runtime),
      object_(object),
      methodName_(methodName),
      original_(object.getPropertyAsFunction(runtime, methodName.c_str())) {

  fjsi::Function proxyFunc = fjsi::Function::createFromHostFunction(
    runtime,
    fjsi::PropNameID::forUtf8(runtime, methodName_),
    count,
    [condition, this](
        fjsi::Runtime& rt,
        const fjsi::Value& thisVal,
        const fjsi::Value* args,
        size_t count) -> fjsi::Value {
      if (condition(rt, args, count)) {
        return original_.callWithThis(rt, thisVal.asObject(rt), args, count);
      }
      return fjsi::Value::undefined();
    });

  object_.setProperty(runtime, methodName_.c_str(), std::move(proxyFunc));
}

JSObjectMethodProxy::~JSObjectMethodProxy() {
  object_.setProperty(runtime_, methodName_.c_str(), std::move(original_));
}
