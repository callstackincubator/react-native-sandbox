cmake_minimum_required(VERSION 3.16)
project(SandboxRegistryTests)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set build type if not specified
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug)
endif()

# Set source files
set(TEST_SOURCES
    SandboxRegistryTests.mm
    main.m
    ../ios/SandboxRegistry.mm
)

# Set include directories
set(INCLUDE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}/../ios
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Create test executable
add_executable(SandboxRegistryTests ${TEST_SOURCES})

# Set include directories
target_include_directories(SandboxRegistryTests PRIVATE ${INCLUDE_DIRS})

# Find and link frameworks
find_library(FOUNDATION_FRAMEWORK Foundation)
find_library(XCTEST_FRAMEWORK XCTest)

if(FOUNDATION_FRAMEWORK)
    target_link_libraries(SandboxRegistryTests ${FOUNDATION_FRAMEWORK})
else()
    # Fallback for systems where find_library doesn't work
    target_link_libraries(SandboxRegistryTests "-framework Foundation")
endif()

if(XCTEST_FRAMEWORK)
    target_link_libraries(SandboxRegistryTests ${XCTEST_FRAMEWORK})
else()
    # Fallback for systems where find_library doesn't work
    target_link_libraries(SandboxRegistryTests "-framework XCTest")
endif()

# Set compiler flags for macOS/iOS
if(APPLE)
    target_compile_options(SandboxRegistryTests PRIVATE
        -Wall
        -Wextra
        -fobjc-arc
    )
    
    # Set deployment target (create simple executable, not bundle)
    set_target_properties(SandboxRegistryTests PROPERTIES
        MACOSX_BUNDLE FALSE
    )
endif()

# Add test
add_test(NAME SandboxRegistryTests COMMAND SandboxRegistryTests)

# Set test properties
set_tests_properties(SandboxRegistryTests PROPERTIES
    ENVIRONMENT "DYLD_LIBRARY_PATH=${CMAKE_BINARY_DIR}/lib"
)

# Custom target for running tests (build + run)
add_custom_target(test
    COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target SandboxRegistryTests
    COMMAND ${CMAKE_BINARY_DIR}/SandboxRegistryTests
    DEPENDS SandboxRegistryTests
    COMMENT "Building and running SandboxRegistry tests"
)

# Custom target for just building
# add_custom_target(build-sandbox-registry
#     COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target SandboxRegistryTests
#     DEPENDS SandboxRegistryTests
#     COMMENT "Building SandboxRegistry tests"
# )

# Print configuration info
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "Source files: ${TEST_SOURCES}")
message(STATUS "Include directories: ${INCLUDE_DIRS}")
message(STATUS "Foundation framework: ${FOUNDATION_FRAMEWORK}")
message(STATUS "XCTest framework: ${XCTEST_FRAMEWORK}")

 