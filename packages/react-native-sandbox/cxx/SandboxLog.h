#pragma once

#include <string>

#ifdef __APPLE__
#ifdef __OBJC__
#import <React/RCTLog.h>
#define SANDBOX_LOG_WARN(fmt, ...) RCTLogWarn(@fmt, ##__VA_ARGS__)
#else
// C++ context on Apple — use stderr as fallback
#include <cstdio>
#define SANDBOX_LOG_WARN(fmt, ...) \
  fprintf(stderr, "[SandboxWarn] " fmt "\n", ##__VA_ARGS__)
#endif
#elif defined(__ANDROID__)
#include <android/log.h>
#define SANDBOX_LOG_WARN(fmt, ...) \
  __android_log_print(             \
      ANDROID_LOG_WARN, "ReactNativeSandbox", fmt, ##__VA_ARGS__)
#else
#include <cstdio>
#define SANDBOX_LOG_WARN(fmt, ...) \
  fprintf(stderr, "[SandboxWarn] " fmt "\n", ##__VA_ARGS__)
#endif
