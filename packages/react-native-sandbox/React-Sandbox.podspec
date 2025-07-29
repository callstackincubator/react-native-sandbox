require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

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
  s.source_files = "ios/**/*.{h,m,mm,cpp,swift}"
  install_modules_dependencies(s)
  s.pod_target_xcconfig    = {
    "HEADER_SEARCH_PATHS" => header_search_paths,
    # "OTHER_CPLUSPLUSFLAGS" => "-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1",
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
  }
end
