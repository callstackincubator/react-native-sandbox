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
