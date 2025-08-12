require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

header_search_paths = [
  "\"$(PODS_TARGET_SRCROOT)/ReactCommon\"",
  "\"$(PODS_ROOT)/Headers/Private/React-Core\"",
  "\"$(PODS_ROOT)/Headers/Private/Yoga\"",
  "\"$(PODS_ROOT)/Headers/Public/ReactCodegen\"",
  "\"$(PODS_ROOT)/Headers/Private/React-RCTFabric\"",
  "\"$(PODS_ROOT)/Headers/Private/ReactCommon\"",
  "\"$(PODS_ROOT)/Headers/Private/RCT-Folly\"",
  "\"$(PODS_ROOT)/Headers/Private/React-Core/CxxUtils\"",
]

# Add Expo-specific header search paths when building for Expo
if ENV['EXPO_MODULE'] == '1'
  header_search_paths << "\"$(PODS_ROOT)/Headers/Public/ExpoModulesCore\""
end

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
  
  # Conditionally disable codegen for Expo builds
  if ENV['EXPO_MODULE'] == '1'
    # For Expo builds, disable codegen by not including the codegenConfig
    s.pod_target_xcconfig = {
      "HEADER_SEARCH_PATHS" => header_search_paths,
      "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
      "GCC_PREPROCESSOR_DEFINITIONS" => "EXPO_MODULE=1",
      "RCT_NEW_ARCH_ENABLED" => "0"  # Disable new architecture for Expo
    }
    s.dependency "ExpoModulesCore"
  else
    # For regular React Native builds, enable codegen
    s.pod_target_xcconfig = {
      "HEADER_SEARCH_PATHS" => header_search_paths,
      "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
    }
  end
  
  install_modules_dependencies(s)
  s.dependency "fmt"
end
