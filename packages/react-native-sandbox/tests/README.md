# SandboxRegistry Tests

This directory contains tests for the `SandboxRegistry` class, which was separated from `SandboxReactNativeDelegate` to maintain single responsibility principle.

## Test Structure

- `SandboxRegistryTests.mm` - Unit tests using XCTest framework
- `CMakeLists.txt` - Complete CMake build system

## Running Tests

### Using NPM/Bun (Recommended)

```bash
# From project root
npm run test:sandbox-registry
# or
bun run test:sandbox-registry
```

### Using CMake Directly

```bash
cd packages/react-native-sandbox/ios/tests

# Modern CMake approach (creates build directory automatically)
cmake -S . -B build
cmake --build build --target test-sandbox-registry

# Or run tests directly
cmake --build build
./build/SandboxRegistryTests
```

### Alternative: Traditional CMake

```bash
cd packages/react-native-sandbox/ios/tests

# Create build directory and configure
mkdir build && cd build
cmake ..
make test-sandbox-registry

# Or just build
make build-sandbox-registry
```

## Test Coverage

The tests verify:

1. **Registry Registration** - Testing `registerSandbox:delegate:`
2. **Registry Retrieval** - Testing `getSandbox:`
3. **Registry Unregistration** - Testing `unregisterSandbox:`
4. **Message Routing** - Testing `routeMessage:toSandbox:`
5. **Separation of Concerns** - Verifying that registry functionality is properly separated from delegate functionality
6. **Concurrent Access** - Testing thread safety of the registry

## Build System Features

The CMake build system provides:

- **Framework Detection** - Automatically finds and links Foundation and XCTest frameworks
- **Cross-Platform Support** - Works on macOS and iOS
- **Custom Targets** - `test-sandbox-registry` for build+run, `build-sandbox-registry` for build only
- **Modern CMake** - Uses `-S` and `-B` flags for automatic directory management
- **Compiler Flags** - Sets appropriate flags for Objective-C++ compilation
- **Error Handling** - Comprehensive error checking and fallbacks

## Test Dependencies

The tests require:
- Foundation framework (automatically detected)
- XCTest framework (automatically detected)
- CMake 3.16 or later
- C++17 compatible compiler

## Build Output

Tests are compiled to `build/SandboxRegistryTests` and can be run directly.

## CMake Targets

- `SandboxRegistryTests` - Main executable target
- `test-sandbox-registry` - Build and run tests
- `build-sandbox-registry` - Build tests only
- `test` - Standard CMake test target

## XCTest Features

The tests use proper XCTest framework:
- `XCTestCase` subclass for test organization
- `setUp` and `tearDown` methods for test isolation
- `XCTAssert*` macros for assertions
- Proper test method naming (`test*` prefix)
- Automatic test discovery and execution

## Troubleshooting

If compilation fails:

1. **Check CMake version**: Ensure you have CMake 3.16+
2. **Check compiler**: Ensure you have a C++17 compatible compiler
3. **Check frameworks**: Foundation and XCTest frameworks should be available on macOS
4. **Clean build**: Remove `build/` directory and reconfigure

```bash
rm -rf build
cmake -S . -B build
cmake --build build --target test-sandbox-registry
``` 