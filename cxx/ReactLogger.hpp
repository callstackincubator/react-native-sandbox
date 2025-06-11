#pragma once

#include <string>
#include <sstream>
#include <thread>
#include <format>

#if __APPLE__
#include <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_MAC
#include <os/log.h>
#define RNLOGGER_HAS_OSLOG 1
#endif
#elif __ANDROID__
#include <android/log.h>
#define RNLOGGER_HAS_ANDROID_LOG 1
#endif

#include <jsi/jsi.h>

namespace facebook::react::logger {

static jsi::Runtime* logRt = nullptr;

enum class LogLevel {
  LLDEBUG,
  LLINFO,
  LLWARN,
  LLERROR
};

inline const char* levelToString(LogLevel level) {
  switch (level) {
    case LogLevel::LLINFO:  return "INFO";
    case LogLevel::LLWARN:  return "WARN";
    case LogLevel::LLERROR: return "ERROR";
    case LogLevel::LLDEBUG: return "DEBUG";
    default:                return "UNKNOWN";
  }
}

inline void logToPlatform(LogLevel level, const std::string& tag, const std::string& finalMsg) {
#if defined(RNLOGGER_HAS_OSLOG)
  os_log_type_t osLogType = OS_LOG_TYPE_DEFAULT;
  switch (level) {
    case LogLevel::LLERROR: osLogType = OS_LOG_TYPE_ERROR; break;
    case LogLevel::LLDEBUG: osLogType = OS_LOG_TYPE_DEBUG; break;
    case LogLevel::LLINFO:  osLogType = OS_LOG_TYPE_INFO;  break;
    case LogLevel::LLWARN:  osLogType = OS_LOG_TYPE_DEFAULT; break;
  }
  os_log_with_type(OS_LOG_DEFAULT, osLogType, "%{public}s", finalMsg.c_str());

#elif defined(RNLOGGER_HAS_ANDROID_LOG)
  int androidLevel = ANDROID_LOG_DEFAULT;
  switch (level) {
    case LogLevel::LLERROR: androidLevel = ANDROID_LOG_ERROR; break;
    case LogLevel::LLDEBUG: androidLevel = ANDROID_LOG_DEBUG; break;
    case LogLevel::LLINFO:  androidLevel = ANDROID_LOG_INFO;  break;
    case LogLevel::LLWARN:  androidLevel = ANDROID_LOG_WARN;  break;
  }
  __android_log_print(androidLevel, tag.c_str(), "%s", message.c_str());

#else
  if (level >= LogLevel::LLWARN) {
    std::cerr << finalMsg << '\n';
  } else {
    std::cout << finalMsg << '\n';
  }
#endif
}

inline void logToConsole(jsi::Runtime* rt, LogLevel level, const std::string& msg) {
  if (!rt) return;

  try {
    jsi::Object global = rt->global();
    if (!global.hasProperty(*rt, "console")) return;
    jsi::Object console = global.getPropertyAsObject(*rt, "console");

    const char* methodName = "log";
    switch (level) {
      case LogLevel::LLERROR: methodName = "error"; break;
      case LogLevel::LLWARN:  methodName = "warn";  break;
      case LogLevel::LLDEBUG: methodName = "debug"; break;
      case LogLevel::LLINFO:  methodName = "log";   break;
    }

    if (!console.hasProperty(*rt, methodName)) return;
    jsi::Function fn = console.getPropertyAsFunction(*rt, methodName);
    fn.call(*rt, jsi::String::createFromUtf8(*rt, msg));
  } catch (...) {
    // silent fail
  }
}

inline void enableConsoleLog(jsi::Runtime* rt) {
  // TODO assert nullptr
  logRt = rt;
}

inline std::string threadIdToString() {
  std::ostringstream ss;
  ss << std::this_thread::get_id();
  return ss.str();
}

inline std::string pointerToString(void const *pointer) {
  std::ostringstream address;
  address << pointer;
  return address.str();
}

inline void log(LogLevel level, const std::string& tag, const std::string& message, jsi::Runtime* argRt = nullptr) {
  std::ostringstream oss;
  oss << "[" << levelToString(level) << "] "
      << std::hex << "[TID:" << std::hash<std::thread::id>{}(std::this_thread::get_id()) << "] "
      << tag << ": " << message;
  std::string finalMsg = oss.str();

  logToPlatform(level, tag, finalMsg);

  if (jsi::Runtime* rt = argRt ? argRt : logRt) {
    logToConsole(rt, level, finalMsg);
  }
}

// Shorthand
inline void logInfo(const std::string& tag, const std::string& msg, jsi::Runtime* rt = nullptr) {
  log(LogLevel::LLINFO, tag, msg, rt);
}
inline void logWarn(const std::string& tag, const std::string& msg, jsi::Runtime* rt = nullptr) {
  log(LogLevel::LLWARN, tag, msg, rt);
}
inline void logError(const std::string& tag, const std::string& msg, jsi::Runtime* rt = nullptr) {
  log(LogLevel::LLERROR, tag, msg, rt);
}
inline void logDebug(const std::string& tag, const std::string& msg, jsi::Runtime* rt = nullptr) {
  log(LogLevel::LLDEBUG, tag, msg, rt);
}

} // namespace react::logging
