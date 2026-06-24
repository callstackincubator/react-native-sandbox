import {useCallback} from 'react'

declare const globalThis: {
  postMessage: (msg: unknown, targetOrigin?: string) => void
  setOnMessage: (cb: (msg: unknown) => void, surfaceId?: string) => void
}

/**
 * Hook for sandbox components to send and receive messages scoped to their
 * own surface when sharing an origin (and therefore a Hermes VM) with other
 * sandboxes.
 *
 * Without this hook:
 * - `globalThis.postMessage(msg)` broadcasts to ALL host views sharing the origin.
 * - `globalThis.setOnMessage(cb)` is last-writer-wins (only one listener).
 *
 * With this hook:
 * - `postMessage` attaches a routing hint so the message is delivered only to
 *   the calling surface's parent view.
 * - `setOnMessage` registers a per-surface listener so every surface receives
 *   incoming sandbox-to-sandbox messages independently.
 *
 * Usage:
 * ```tsx
 * function MyWidget({__sandboxSurfaceId}: Props) {
 *   const {postMessage, setOnMessage} = useSurfaceMessaging(__sandboxSurfaceId);
 *
 *   useEffect(() => {
 *     const unsubscribe = setOnMessage((msg) => console.log('received', msg));
 *     return unsubscribe;
 *   }, [setOnMessage]);
 *
 *   postMessage({type: 'hello'});
 * }
 * ```
 *
 * @param surfaceId - The `__sandboxSurfaceId` prop injected by the native
 *   side into initialProperties. If undefined, falls back to broadcast/shared.
 */
export function useSurfaceMessaging(surfaceId?: string) {
  const postMessage = useCallback(
    (msg: unknown, targetOrigin?: string) => {
      if (targetOrigin) {
        // Cross-origin: forward directly without adding surface routing hint.
        // The native side routes by origin, not by surface ID.
        globalThis.postMessage(
          typeof msg === 'object' && msg !== null ? msg : {data: msg},
          targetOrigin
        )
        return
      }
      // Per-surface: attach routing hint for the host view
      const payload =
        typeof msg === 'object' && msg !== null ? {...msg} : {data: msg}
      if (surfaceId) {
        ;(payload as Record<string, unknown>).__sandboxSurfaceId = surfaceId
      }
      globalThis.postMessage(payload)
    },
    [surfaceId]
  )

  const setOnMessage = useCallback(
    (cb: (msg: unknown) => void) => {
      globalThis.setOnMessage(cb, surfaceId)
      // Return a cleanup function that unregisters the per-surface listener
      return () => {
        globalThis.setOnMessage(() => {}, surfaceId)
      }
    },
    [surfaceId]
  )

  return {postMessage, setOnMessage}
}
