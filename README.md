# react-native-multinstance

![Platform: iOS](https://img.shields.io/badge/platform-iOS-blue.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

- [Project Overview](#project-overview)
- [API Example](#api-example)
  - [Host Application (`HostApp`)](#host-application-hostapp)
  - [Sandboxed Application (`SandboxApp`)](#sandboxed-application-sandboxapp)
- [⚠️ Security Considerations](#%EF%B8%8F-security-considerations)
  - [TurboModules](#turbomodules)
  - [Performance](#performance)
  - [File System & Storage](#file-system--storage)
  - [Platform-Specific Considerations](#platform-specific-considerations)

`react-native-multinstance` is a library for running multiple, isolated React Native instances within a single application. This allows you to embed third-party or feature-specific "micro-apps" in a sandboxed environment, preventing uncontrolled interference with the main app by providing a clear API for communication (`postMessage`/`onMessage`).

## Project Overview

This project was born from the need to safely run third-party code within a react-native application. The core requirements are:

- **Isolation:** Run external code in a secure, sandboxed environment.
- **Safety:** Prevent direct access to the host application's code and data.
- **Communication:** Provide a safe and explicit API for communication between the host and the sandboxed instances.

> Note that `postMessage` only supports serializable data (similar to [`Window.postMessage`](https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage#message) in web browsers), meaning no functions, native state, or non-serializable objects can be passed.

`react-native-multinstance` provides the API to create these sandboxed React Native instances with a simple component-based API, requiring no native code to be written by the consumer.

This project is structured as a monorepo.

- [`packages/react-native-multinstance`](./packages/react-native-multinstance/): the core library.
- [`packages/examples/side-by-side`](./packages/examples/side-by-side/README.md): An example application with two sandbox instances.
- [`packages/examples/recursive`](./packages/examples/recursive/README.md): An example application with few nested sandbox instances.

To run the examples:

1. Install dependencies:

    ```sh
    yarn
    cd packages/examples/<specific-example>
    yarn
    ```

1. Run the example application:

    ```sh
    yarn ios
    # or
    yarn android
    ```


## API Example

Here is a brief overview of how to use the library.

### Host Application (`HostApp`)

```tsx
import React, { useRef } from 'react';
import { View, Button } from 'react-native';
import SandboxReactNativeView, { SandboxReactNativeViewRef } from 'react-native-multinstance';

function HostApp() {
  const sandboxRef = useRef<SandboxReactNativeViewRef>(null);

  const handleMessage = (message) => console.log("Message received from sandbox:", message);
  const handleError = (error) => console.error("Error in sandbox:", error);
  const sendMessageToSandbox = () => sandboxRef.current?.postMessage({ data: "Hello from the host!" });

  return (
    <View>
      <Button onPress={sendMessageToSandbox} title="Send to Sandbox" />
      <SandboxReactNativeView
        ref={sandboxRef}
        jsBundleName={"sandbox"} // The name of the JS bundle for the sandbox
        moduleName={"SandboxApp"} // The registered module name in the sandbox
        onMessage={handleMessage}
        onError={handleError}
      />
    </View>
  );
}
```

### Sandboxed Application (`SandboxApp`)

```tsx
import React, { useState, useEffect, useCallback } from 'react';
import { View, Button, Text } from 'react-native';

// No import required API available through global
declare global {
  var postMessage: (message: object) => void;
  var setOnMessage: (handler: (payload: object) => void) => void;
}

function SandboxApp() {
  const [data, setData] = useState<string | undefined>();

  // Listen for messages from the host
  const onMessage = useCallback((payload: unknown) => {
    setData(JSON.stringify(payload));
  }, []);

  useEffect(() => {
    globalThis.setOnMessage(onMessage);
  }, [onMessage]);

  // Send a message back to the host
  const postMessageToHost = () => {
    // `postMessage` is also injected into the global scope
    globalThis.postMessage({ data: 'Hello from the Sandbox!' });
  };

  return (
    <View>
      <Button onPress={postMessageToHost} title="Send Data to Host" />
      <Text>Received: {data}</Text>
    </View>
  );
}

AppRegistry.registerComponent("SandboxApp", () => App);
```

## ⚠️ Security Considerations

### TurboModules

A primary security concern when running multiple React Native instances is the potential for state sharing through native modules, especially **TurboModules**.

- **Static State:** If a TurboModule is implemented with static fields or as a singleton in native code, this single instance will be shared across all React Native instances (the host and all sandboxes).
- **Data Leakage:** One sandbox could use a shared TurboModule to store data, which could then be read by another sandbox or the host. This breaks the isolation model.
- **Unintended Side-Effects:** A sandbox could call a method on a shared module that changes its state, affecting the behavior of the host or other sandboxes in unpredictable ways.

To address this, `react-native-multinstance` allows you to provide a **whitelist of allowed TurboModules** for each sandbox instance via the `allowedTurboModules` prop. Only the modules specified in this list will be accessible from within the sandbox, significantly reducing the attack surface. It is critical to only whitelist modules that are stateless or are explicitly designed to be shared safely.

**Default Whitelist:** By default, only `NativeMicrotasksCxx` is whitelisted. Modules like `NativePerformanceCxx`, `PlatformConstants`, `DevSettings`, `LogBox`, and other third-party modules are *not* whitelisted.

### Performance

- **Resource Exhaustion (Denial of Service):** A sandboxed instance could intentionally or unintentionally consume excessive CPU or memory, potentially leading to a denial-of-service attack that slows down or crashes the entire application. The host should be prepared to monitor and terminate misbehaving instances.

### File System & Storage

- **Persistent Storage Conflicts:** Standard APIs like `AsyncStorage` may not be instance-aware, potentially allowing a sandbox to read or overwrite data stored by the host or other sandboxes. Any storage mechanism must be properly partitioned to ensure data isolation.

### Platform-Specific Considerations

- **iOS `NSNotificationCenter`:** The underlying React Native framework uses the default `NSNotificationCenter` for internal communication. Because the same framework instance is shared between the host and sandboxes, it is theoretically possible for an event in one JS instance to trigger a notification that affects another. This could lead to unintended state changes or interference. While not observed during development, this remains a potential risk.
