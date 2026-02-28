cmake_minimum_required(VERSION 3.13)
project(rnsandbox)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(fbjni REQUIRED CONFIG)
find_package(ReactAndroid REQUIRED CONFIG)

add_library(${PROJECT_NAME} SHARED
  SandboxJSIInstaller.cpp
  SandboxBindingsInstaller.cpp
)

target_include_directories(${PROJECT_NAME}
  PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
)

target_link_libraries(${PROJECT_NAME}
  fbjni::fbjni
  ReactAndroid::jsi
  ReactAndroid::reactnative
  android
  log
)
