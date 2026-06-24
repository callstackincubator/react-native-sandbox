# Origin Pooling Demo

Validates features of sandboxes sharing the same origin.  

## Origin-based Pooling

Sandboxes with the same `origin` prop share a single ReactHost / Hermes VM.

- **Alpha** sandboxes share origin `alpha` → same VM
- **Beta** sandboxes share origin `beta` → same VM
- **Isolated** sandboxes get their own VM every time (no origin)

Use the `+ Alpha`, `+ Beta`, and `+ Isolated` buttons to dynamically add
sandboxes. Each card has a **Ping** button and a **✕** button
to remove itself.

## Lazy Kill

When the last sandbox for an origin unmounts, the underlying ReactHost is
**not** destroyed immediately — it lingers for 2 seconds (`idleTTL={2000}`).
If a new sandbox with the same origin mounts within that window, it reuses
the warm host (no cold start). Compare the `render` time of a cold start
vs a warm re-mount.

## Running

```bash
# From repo root
yarn
cd apps/origin-pooling
npx react-native run-ios
# or
npx react-native run-android
```

## Multi-Origin Messaging Approaches

This demo showcases two approaches for per-surface messaging in sandboxes
that share a Hermes VM. Alpha sandboxes use the convention-based approach,
while Beta sandboxes use the library-based approach.

### Library approach (`useSurfaceMessaging`)

Import the hook from `@callstack/react-native-sandbox`:

```tsx
import {useSurfaceMessaging} from '@callstack/react-native-sandbox'

function MySandboxWidget({__sandboxDelegateId}: Props) {
  const {postMessage, setOnMessage} = useSurfaceMessaging(__sandboxDelegateId)

  // Send to host (per-surface routed)
  postMessage({type: 'hello'})

  // Send to another origin
  postMessage({type: 'ping'}, 'beta')

  // Receive messages (per-surface)
  setOnMessage((msg) => console.log('received', msg))
}
```

The hook handles delegate ID injection and per-surface listener registration
internally. This is the recommended approach when you already depend on the
sandbox library.

See: `SandboxApp.tsx`

### Convention approach (no library dependency)

Use `globalThis.postMessage` and `globalThis.setOnMessage` directly,
following the delegate ID conventions:

```tsx
declare const globalThis: {
  postMessage: (msg: unknown, targetOrigin?: string) => void
  setOnMessage: (cb: (msg: unknown) => void, delegateId?: string) => void
}

function MySandboxWidget({__sandboxDelegateId}: Props) {
  // Send to host — spread delegateId into payload for per-surface routing
  const send = (msg: Record<string, unknown>, targetOrigin?: string) => {
    const payload = !targetOrigin && __sandboxDelegateId
      ? {...msg, __sandboxDelegateId}
      : msg
    globalThis.postMessage(payload, targetOrigin)
  }

  // Send to another origin (no delegateId needed)
  send({type: 'ping'}, 'alpha')

  // Receive messages — pass delegateId as 2nd arg for per-surface listener
  globalThis.setOnMessage((msg) => {
    console.log('received', msg)
  }, __sandboxDelegateId)
}
```

This approach has zero library dependencies — useful when the sandbox JS
bundle is built independently or when you want to minimize the sandbox's
dependency footprint.

See: `SandboxAppConvention.tsx`

### Key differences

| | Library | Convention |
|---|---|---|
| Import needed | `@callstack/react-native-sandbox` | None |
| Delegate routing | Handled by hook | Manual (`__sandboxDelegateId` in payload) |
| Cross-origin send | `postMessage(msg, origin)` | `globalThis.postMessage(msg, origin)` |
| Per-surface listen | `setOnMessage(cb)` | `globalThis.setOnMessage(cb, delegateId)` |
