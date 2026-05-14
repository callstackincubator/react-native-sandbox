import {useCallback} from 'react'

declare const globalThis: {
  postMessage: (msg: unknown, targetOrigin?: string) => void
  setOnMessage: (cb: (msg: unknown) => void, delegateId?: string) => void
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
 * function MyWidget({__sandboxDelegateId}: Props) {
 *   const {postMessage, setOnMessage} = useSurfaceMessaging(__sandboxDelegateId);
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
 * @param delegateId - The `__sandboxDelegateId` prop injected by the native
 *   side into initialProperties. If undefined, falls back to broadcast/shared.
 */
export function useSurfaceMessaging(delegateId?: string) {
  const postMessage = useCallback(
    (msg: unknown, targetOrigin?: string) => {
      if (targetOrigin) {
        // Cross-origin: forward directly without adding delegate routing hint.
        // The native side routes by origin, not by delegate ID.
        globalThis.postMessage(
          typeof msg === 'object' && msg !== null ? msg : {data: msg},
          targetOrigin
        )
        return
      }
      // Per-surface: attach routing hint for the host view
      const payload =
        typeof msg === 'object' && msg !== null ? {...msg} : {data: msg}
      if (delegateId) {
        ;(payload as Record<string, unknown>).__sandboxDelegateId = delegateId
      }
      globalThis.postMessage(payload)
    },
    [delegateId]
  )

  const setOnMessage = useCallback(
    (cb: (msg: unknown) => void) => {
      globalThis.setOnMessage(cb, delegateId)
      // Return a cleanup function that unregisters the per-surface listener
      return () => {
        globalThis.setOnMessage(() => {}, delegateId)
      }
    },
    [delegateId]
  )

  return {postMessage, setOnMessage}
}
