---
marp: true
title: react-native-multi-instance
theme: default
paginate: true
style: |
  .columns {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 1rem;
  }
  pre > code {
    font-size: 24px !important;
  }
---

<!-- footer: "[1] module work in progress\n[2] name work in progress" -->

# react-native-multinstance<sup>[1][2]</sup>

Run multiple isolated React Native apps (micro apps) in the same app.

---

<!-- footer: "" -->

## 💡 **Why** it exists

Client came to us with requirements:

- Run 3rd-party code in an safe environemnt (isolated sandbox)
- No direct access to "host" application code
- While allowing partners to extend the app's functionality.
- Communication `host <-> sandbox`  allowed through safe API

<!--
  1. mention worklets
  -->

---

<!-- footer: "" -->

## ❓ **What** react-native-multinstance offer

- Easy creation of sandbox react-native instances: no native code required
- Isolated `RCTInstance`/`JSContext` that works like an sandbox

---

## 🧩 API Overview

<div class="columns">
<div>

🗄️ Host

```tsx
...
import SandboxReactNativeView, {SandboxReactNativeViewRef}
  from 'react-native-multinstance';

function App() {
  const sandboxRef = useRef<SandboxReactNativeViewRef>(null);

  const onMessage = (msg) => console.log("Recieved:", msg);
  const onError = (err) => console.log("Error:", err);
  const postMessage = () => sandboxRef?.current.postMessage(
    { data: "Hello from the host!" });

  return (
    <View>
      <Button onPress={onPress} title="Send to sandbox" />
      ...
      <SandboxReactNativeView ref={sandbox1Ref}
        jsBundleName={"sandbox"}
        moduleName={"SandboxApp"}
        onMessage={onMessage}
        onError={onError}
        initialProperties={...} launchOptions={...} />
    </View>
  );
}

AppRegistry.registerComponent("HostApp", () => App);
```

</div>
<div>

📦 Sandbox

```tsx
...
import MultiReactMediatorModule from
  'react-native-multinstance';

type AppProps = { contextId: string };

function App({contextId}: AppProps) {
  const [data, setData] = useState<string | undefined>();

  const onMessage = useCallback(
    (payload: unknown) => setData(JSON.stringify(payload)), []);

  useEffect(() => MultiReactMediatorModule
    .registerRuntime(`host_${contextId}`, onMessage), []);

  const postMessage = () => MultiReactMediatorModule
    .postMessage({ data: 'Hello from Sandbox!' },
    `${contextId}_host`);

  return (
    <View>
      <Button onPress={postMessage} title="Send Data" />
      <Text>Recieved: {data}</Text>
    </View>
  );
}

AppRegistry.registerComponent("SandboxApp", () => App);
```

</div>
</div>

---

## Demo 😅

---

## ⚠️ Risks and Limitations

1. Security: Turbomodules (static memory)
2. Error handling: All sort of errors (not only JS error but loading error and onther)
3. iOS `[NSNotificationCenter defaultCenter]` with `object:nil` - didn't shoot in the leg yet 😅

---

## 🔮 Next

1. MVP
   1. Error handling
   2. Security: while list of allowed turbomodules
   3. Project structure (monorepo/workspaces)
2. Improve Sandbox API (Extra)
3. Support of "loading" overlay
4. Support functions (not-only UI) components (worlets like API)
5. Re:pack integration (as part of module federalization feature)
6. Dev experience
   1. Different target names in metro

---

## Extra

---

## 🧩 API Overview v0.2

<div class="columns">
<div>

🗄️ Host

```tsx
...
import SandboxReactNativeView, {SandboxReactNativeViewRef}
  from 'react-native-multinstance';

function App() {
  const sandboxRef = useRef<SandboxReactNativeViewRef>(null);

  const onMessage = (msg) => console.log("Recieved:", msg);
  const onError = (err) => console.log("Error:", err);
  const postMessage = () => sandboxRef?.current.postMessage(
    { data: "Hello from the host!" });

  return (
    <View>
      <Button onPress={onPress} title="Send to sandbox" />
      ...
      <SandboxReactNativeView ref={sandbox1Ref}
        jsBundleName={"sandbox"}
        moduleName={"SandboxApp"}
        onMessage={onMessage}
        onError={onError}
        initialProperties={...} launchOptions={...} />
    </View>
  );
}

AppRegistry.registerComponent("HostApp", () => App);
```

</div>
<div>

📦 Sandbox

```diff
...
- import MultiReactMediatorModule from
-  'react-native-multinstance';

- type AppProps = { contextId: string };

function App() {
  const [data, setData] = useState<string | undefined>();

  const onMessage = useCallback(
    (payload: unknown) => setData(JSON.stringify(payload)), []);

-  useEffect(() => MultiReactMediatorModule
-    .registerRuntime(`host_${contextId}`, onMessage), []);
+  useEffect(() => useOnMessage(onMessage), []);

-  const postMessage = () => MultiReactMediatorModule
-    .postMessage({ data: 'Hello from Sandbox!' },
-    `${contextId}_host`);
+  const postMessage = () =>
+    global.postMessage({ data: 'Hello from Sandbox!' });

  return (
    <View>
      <Button onPress={postMessage} title="Send Data" />
      <Text>Recieved: {data}</Text>
    </View>
  );
}

AppRegistry.registerComponent("SandboxApp", () => App);
```

</div>
</div>

---

The End. Any feedback is appreciated 💗
