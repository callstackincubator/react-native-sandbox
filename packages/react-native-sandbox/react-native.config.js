module.exports = {
  dependency: {
    platforms: {
      android: {
        componentDescriptors: ['SandboxReactNativeViewComponentDescriptor'],
        // Disable autolinking's default CMake integration — the JNI library
        // is built by the app-level CMakeLists.txt via the codegen pipeline,
        // so an additional cmake target from autolinking would conflict.
        cmakeListsPath: null,
      },
    },
  },
}
