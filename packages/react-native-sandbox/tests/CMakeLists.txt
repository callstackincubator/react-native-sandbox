cmake_minimum_required(VERSION 3.16)
project(SandboxRegistryCppTests)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug)
endif()

set(CPP_TEST_SOURCES
    SandboxRegistryTest.cpp
    ../ios/SandboxRegistry.cpp
)

set(INCLUDE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}/../ios
    ${CMAKE_CURRENT_SOURCE_DIR}
)

include(FetchContent)

FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG release-1.12.1
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

FetchContent_Declare(
    fmt
    GIT_REPOSITORY https://github.com/fmtlib/fmt.git
    GIT_TAG 10.1.1
)
FetchContent_MakeAvailable(fmt)

set(TEST_EXECUTABLE_NAME SandboxRegistryCppTests)

add_executable(${TEST_EXECUTABLE_NAME} ${CPP_TEST_SOURCES})
target_include_directories(${TEST_EXECUTABLE_NAME} PRIVATE ${INCLUDE_DIRS})

target_link_libraries(${TEST_EXECUTABLE_NAME} 
    gtest 
    gtest_main 
    gmock 
    gmock_main
    fmt::fmt
)

target_compile_options(${TEST_EXECUTABLE_NAME} PRIVATE
    -Wall
    -Wextra
    -std=c++17
)

enable_testing()
add_test(NAME ${TEST_EXECUTABLE_NAME} COMMAND ${TEST_EXECUTABLE_NAME}) 