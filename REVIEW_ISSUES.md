# PR #19 — Remaining Review Issues

Issues identified during code review that are not yet addressed.

## Critical

### Security
- **C-4. Android bypasses `isPermittedFrom` — allowedOrigins not enforced**
  `SandboxJSIInstaller.cpp` — `JNISandboxDelegate::routeMessage` and the `postMessage` JSI function deliver messages with zero permission checks. On iOS, `routeMessage` checks `registry.isPermittedFrom()`. Additionally, `registerSandbox` is called with an empty `std::set<std::string>()` for `allowedOrigins`, so even if the check were added, everything would be blocked. The allowed origins need to be read from the Kotlin delegate.

### Breaking Changes
- **C-5. `BubblingEventHandler` changed to `DirectEventHandler`**
  `specs/NativeSandboxReactNativeView.ts` — `onMessage` and `onError` changed event types. This changes codegen output and event registration names. Existing consumers relying on bubbling behavior will silently break. Should be called out in release notes.

### Fragile Internals
- **C-6. `reloadWithNewBundleSource` uses deep reflection on RN internals**
  `SandboxReactNativeDelegate.kt` — Reflectively accesses `ReactHostImpl.reactHostDelegate` (private), modifies a `final` field via `accessFlags` reflection. Will break across RN versions and may fail on Android 14+ (JDK 17 module restrictions). The fallback (full rebuild) exists, but the reflection is a significant maintenance burden.

## Warnings

### Thread Safety
- **W-2. `sharedHosts` static map is not thread-safe**
  `SandboxReactNativeDelegate.kt` — A plain `mutableMapOf` in `companion object`, read/written from `loadReactNativeView` and `cleanup`. No synchronization. If `cleanup()` is called off the UI thread, this is a data race.

- **W-7. `registerSandbox` silently overwrites `allowedOrigins` for existing origin**
  `SandboxRegistry.cpp` — A second registration with the same origin but different permissions overwrites the first delegate's permissions. Could be privilege escalation or denial.

### JNI Correctness
- **W-3. Missing JNI exception checks after `CallVoidMethod`**
  `SandboxJSIInstaller.cpp` — Multiple `env->CallVoidMethod(...)` calls without `ExceptionCheck()`. A pending Java exception propagates unpredictably.

### API / Behavioral Correctness
- **W-5. `SandboxContextWrapper.getApplicationContext()` returns `this`**
  `SandboxReactNativeDelegate.kt` — Returning the wrapper instead of the real `Application` causes `ClassCastException` when code does `context.applicationContext as Application`.

- **W-6. `createBundleLoader` uses `createFileLoader` for HTTP URLs**
  `SandboxReactNativeDelegate.kt` — `JSBundleLoader.createFileLoader` expects a local file path. May not handle HTTP URLs in all RN versions.

- **W-8. `SandboxRegistry` is now 1:N but iOS still calls `unregister(origin)`**
  `SandboxRegistry.cpp` — Registry changed from 1 to N delegates per origin, but iOS code still calls `unregister(origin)` which removes all delegates. If two views share an origin, destroying one nukes the other.

### iOS Regression
- **W-9. Reload on bundle source change removed on iOS**
  `SandboxReactNativeViewComponentView.mm` — The `RCTHost+Internal.h` import and `[host reload]` call were removed. Changing `jsBundleSource` after initial load no longer triggers a reload on iOS.

### Versioning / Dependencies
- **W-11. Version downgrade 0.4.1 to 0.4.0**
  `package.json` — If 0.4.1 was published, this is a conflict. Combined with the breaking event handler change, should be 0.5.0.

- **W-12. Peer dependency widened to `*`**
  `package.json` — Claims compatibility with every version of React/RN, but Android implementation requires RN 0.78+. Should keep `"react-native": ">=0.78.0"`.

### Fragile Internals
- **W-13. ABI-compatible forward declarations in `SandboxBindingsInstaller.h`**
  Manually duplicates the vtable layout of `ReactInstance`, `BindingsInstaller`, `JBindingsInstaller`. Any change in a future RN release produces silent UB.

## Nits

### Code Duplication / Cleanup
- **N-2. Unused includes** — `#include <iostream>` in `SandboxRegistry.cpp`, `#include <memory>` in `ISandboxDelegate.h`.
- **N-3. Redundant `-std=c++17`** in `tests/CMakeLists.txt` (already set via `CMAKE_CXX_STANDARD`).

### Consistency
- **N-4. Inconsistent library loading** — `SandboxJSIInstaller.kt` uses `System.loadLibrary`, `SandboxBindingsInstaller.kt` uses `SoLoader.loadLibrary`. Prefer `SoLoader` for RN.
- **N-5. `recursive_mutex` is unnecessary** in `SandboxRegistry.h` — no recursive locking occurs. Use `std::mutex`.

### Visibility / Encapsulation
- **N-6. `SandboxReactNativeView` fields should have restricted visibility** — `loadScheduled`, `needsLoad`, `onAttachLoadCallback` are implementation details that should be `internal`.

### Logging
- **N-7. `FilteredReactPackage` logs `Log.w` for every blocked module** — could be dozens per load. Use `Log.d`.

### CI
- **N-8. CI ktlint uses `latest` without version pinning** — can break CI without code changes.

### Scope
- **N-9. p2p-chat changes are unrelated** — Friendship protocol simplification, `Pressable` migration, comment cleanup should be a separate PR.

### Formatting
- **N-10. Missing trailing newlines** in several `cxx/` headers.

### Documentation
- **N-11. `react-native.config.js` sets `cmakeListsPath: null`** — correct but deserves a comment explaining why.

## Test Coverage Gaps

1. No test for `allowedOrigins` overwrite on second registration with same origin.
2. No test for `unregisterDelegate` with an unknown delegate (should be a no-op).
3. No test for `findAll` with a non-existent origin.
4. No test verifying `reset()` releases delegate `shared_ptr` references.
