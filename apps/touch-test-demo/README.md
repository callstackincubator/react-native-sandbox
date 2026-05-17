# Touch Test Demo

Reproduces and tests touch isolation bugs between host and sandbox React Native surfaces. The app deliberately aligns sandbox button view tags with host button view tags to expose tag collision issues.

## Background: Android vs iOS tag resolution

React Native assigns each native view an integer tag used internally to route touch events. On iOS, each React surface (host and sandbox) gets its own tag namespace — tags are scoped per surface, so collisions between host and sandbox are impossible by design.  On Android, view tags are allocated from a single global counter shared across all surfaces in the process, meaning that tags in the host app and in a sandbox could occur.


## What it tests

### Test 1: Touch Bleed

A host button and a sandbox button share the same React view tag (34). When you tap the sandbox button, the test checks whether the host button also receives the touch event.  Touch events should be handled only in the proper surface.

### Test 2: Overlay over Sandbox

A host overlay card is rendered on top of the sandbox surface. A sandbox button is padded to share the same tag (92) as the host overlay button. The test checks:

- Overlay buttons receive touches normally
- The overlay card blocks touches from reaching sandbox buttons underneath
- Sandbox buttons not covered by the overlay still work
- The grey backdrop area blocks sandbox touches

## How the tag alignment works

The sandbox component (`Sandbox.tsx`) inserts invisible padding `View` elements before specific buttons to consume tag IDs and push button tags to target values. Each padding view consumes ~2 tags on Android.

Current alignment:
- Sandbox Button 2 → tag 34 (matches host button in Test 1)
- Sandbox Button 3 → tag 92 (matches host overlay button in Test 2)

Tag values may be device/platform-dependent. If they drift after changes, adjust the `PADDING_BEFORE_BUTTON` values in `Sandbox.tsx`.

> **Fragility note:** The padding counts are sensitive to the number of host views rendered before the sandbox surface starts, React Native's internal tag allocation strategy, and the number of views inside the sandbox before each button. These may change across RN versions. The on-screen `(tag: N)` labels in the demo UI make it easy to spot drift — if the displayed tags no longer match the expected collision values, update `PADDING_BEFORE_BUTTON` in `Sandbox.tsx` accordingly.

## Build steps (Android release)

All commands run from the monorepo root (`react-native-sandbox/`).

### 1. Install dependencies

```bash
yarn install
```

### 2. Bundle the sandbox JS

From `apps/touch-test-demo/`:

```bash
npx react-native bundle \
  --platform android \
  --dev false \
  --entry-file sandbox.js \
  --bundle-output android/app/src/main/assets/sandbox.android.bundle \
  --assets-dest android/app/src/main/res/
```

### 3. Generate codegen artifacts

From `apps/touch-test-demo/android/`:

```bash
./gradlew :callstack_react-native-sandbox:generateCodegenArtifactsFromSchema
```

### 4. Build the release APK

From `apps/touch-test-demo/android/`:

```bash
./gradlew assembleRelease
```

The APK is at `android/app/build/outputs/apk/release/app-release.apk`.

### 5. Install and launch

```bash
adb install android/app/build/outputs/apk/release/app-release.apk
adb shell am start -n com.touchtestdemo/.MainActivity
```
