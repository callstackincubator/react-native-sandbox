# Security Demo

![Platform: iOS](https://img.shields.io/badge/platform-iOS-blue.svg)

This demo showcases a side-by-side comparison between a regular React Native component and one executed inside a `react-native-sandbox`ed environment. The `CrashIfYouCanDemo` component intentionally triggers various types of failures — such as accessing undefined globals, overwriting global variables, invoking blocked native modules, infinite loops. When run in the main app context, these actions can crash or destabilize the app. However, when isolated inside the `SandboxReactNativeView`, they are safely contained without affecting the host application. This demonstrates how sandboxing can enhance reliability and security in untrusted or third-party React Native code execution.

## Screenshot

<div style="display: flex; flex-wrap: wrap; gap: 10px; align: center">
  <img src="./docs/screenshot.png" width="240" />
</div>
