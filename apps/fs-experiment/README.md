# File System & Storage Isolation

![Platform: iOS](https://img.shields.io/badge/platform-iOS-blue.svg)

This example demonstrates **TurboModule substitutions** — transparently replacing native module implementations inside a sandbox with scoped, per-origin alternatives. The app uses a split-screen layout where the host and sandbox run the same UI, but the sandbox can swap `react-native-fs` (iOS only), `react-native-file-access`, and `@react-native-async-storage/async-storage` for sandboxed implementations that jail file paths and scope storage per origin.

> **Note:** `react-native-fs` (v2) relies on the legacy `NativeModules` bridge and does not support TurboModules / New Architecture. On **Android** `NativeModules.RNFSManager` is `null` so RNFS is **disabled** there. On **iOS** it still works thanks to RN's bridge interop layer. See [itinance/react-native-fs#1221](https://github.com/itinance/react-native-fs/issues/1221).

## Screenshot

<div align="center">
  <img src="./docs/screenshot.png" width="240" />
</div>
