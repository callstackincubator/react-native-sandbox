#pragma once

#include <jsi/jsi.h>

namespace rnsandbox {

// Clear the __FUSEBOX_HAS_FULL_CONSOLE_SUPPORT__ runtime global so that
// LogBoxData.addLog() won't create the "Open debugger to view warnings."
// migration toast inside sandboxed React Native instances.
//
// Must run BEFORE bundle evaluation — the flag is set by
// RuntimeTarget::installConsoleHandler during runtime init, and read by
// LogBoxData.addLog() as soon as the first console.warn fires.
inline void disableFuseboxLogBoxToast(facebook::jsi::Runtime& runtime) {
  facebook::jsi::Object global = runtime.global();
  if (global.hasProperty(runtime, "__FUSEBOX_HAS_FULL_CONSOLE_SUPPORT__")) {
    global.setProperty(
        runtime,
        "__FUSEBOX_HAS_FULL_CONSOLE_SUPPORT__",
        facebook::jsi::Value::undefined());
  }
}

} // namespace rnsandbox
