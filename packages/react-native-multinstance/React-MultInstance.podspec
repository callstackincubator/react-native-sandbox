require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "React-MultInstance"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = "https://github.com/callstackincubator/multi-instance-poc" # Please update this
  s.license      = "MIT"
  s.authors      = { "Alex Babrykovich" => "aliaksandr.babrykovich@callstack.com" } # Please update this
  s.platforms    = { :ios => "12.4" }
  s.source       = { :git => "https://github.com/callstackincubator/multi-instance-poc.git", :tag => "#{s.version}" } # Please update this
  s.source_files = "ios/**/*.{h,m,mm,cpp,swift}"
  s.dependency "React-Core"
  s.dependency "React-RCTAppDelegate"
  s.dependency "ReactAppDependencyProvider"
  s.dependency "ReactCommon"
  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    "GCC_PREPROCESSOR_DEFINITIONS" => "$(inherited) FOLLY_NO_CONFIG FOLLY_CFG_NO_COROUTINES",
    "OTHER_CPLUSPLUSFLAGS" => "-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1",
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
  }
end
