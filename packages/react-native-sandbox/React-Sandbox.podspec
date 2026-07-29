require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

has_expo = File.exist?(File.join(__dir__, "../../node_modules/expo-modules-core"))

header_search_paths = [
  "\"$(PODS_TARGET_SRCROOT)/ReactCommon\"",
  "\"$(PODS_ROOT)/Headers/Private/React-Core\"",
  "\"$(PODS_ROOT)/Headers/Private/Yoga\"",
  "\"$(PODS_ROOT)/Headers/Public/ReactCodegen\"",
]

Pod::Spec.new do |s|
  s.name         = "React-Sandbox"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = "https://github.com/callstackincubator/react-native-sandbox"
  s.license      = "MIT"
  s.authors      = { "Alex Babrykovich" => "aliaksandr.babrykovich@callstack.com" }
  s.platforms    = { :ios => "12.4" }
  s.source       = { :git => "https://github.com/callstackincubator/react-native-sandbox.git", :tag => "#{s.version}" }
  core_sources = ["ios/*.{h,m,mm,cpp}", "cxx/**/*.{h,cpp}"]
  expo_sources = has_expo ? ["ios/Expo/**/*.{h,m,mm,swift}"] : []
  s.source_files = core_sources + expo_sources
  # All headers use ObjC++ types (std::string, std::shared_ptr, etc.) that Swift cannot
  # import. Marking them private keeps them out of the generated umbrella header so that
  # the Swift compiler can build SandboxAppContextBridge.swift without hitting C++ errors.
  s.private_header_files = ["ios/*.h", "ios/Expo/*.h", "cxx/**/*.h"]
  install_modules_dependencies(s)
  s.dependency "fmt"

  expo_xcconfig = {}
  if has_expo
    s.dependency "ExpoModulesCore"
    s.dependency "Expo"
    expo_xcconfig = { "OTHER_CPLUSPLUSFLAGS" => "$(inherited) -DRNS_HAS_EXPO_MODULES=1" }
  end

  s.pod_target_xcconfig = {
    "HEADER_SEARCH_PATHS" => header_search_paths + ["\"$(PODS_TARGET_SRCROOT)/cxx\""],
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
  }.merge(expo_xcconfig)
end
