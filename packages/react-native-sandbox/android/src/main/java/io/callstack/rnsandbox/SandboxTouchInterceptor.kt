package io.callstack.rnsandbox

import android.app.Activity
import android.graphics.Rect
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.Window
import java.lang.ref.WeakReference

/**
 * Intercepts touch events at the Activity window level to prevent the host's
 * ReactSurfaceView from processing touches that land inside sandbox views.
 *
 * ## Background
 *
 * The host and sandbox Fabric surfaces share the same global React view tag
 * namespace on Android. When a sandbox internal view has the same tag as a
 * host view, touch events from the sandbox "bleed" into the host — the host's
 * Fabric C++ renderer resolves the touch to its own view at the colliding tag.
 *
 * ## Approach
 *
 * The interceptor wraps the Activity's [Window.Callback], which is the
 * first thing that sees touch events before they enter the view tree. For
 * every touch that lands within a sandbox's screen bounds, the interceptor
 * either:
 *
 * - **Not obscured**: Routes the event directly to the sandbox's child
 *   [ReactSurfaceView] via [SandboxReactNativeView.dispatchTouchEventToChild],
 *   bypassing the host's Fabric touch processing entirely.
 *
 * - **Obscured by an overlay**: Temporarily hides the sandbox's children
 *   (setting them [View.INVISIBLE]) and re-dispatches through the normal
 *   [Window.Callback] delegate. This lets Android's standard view dispatch
 *   deliver the event to the overlay, while the host's Fabric renderer skips
 *   the invisible sandbox surface during hit-testing. Children visibility is
 *   restored immediately after dispatch (synchronous, no visual flicker).
 *
 * ## Z-order awareness
 *
 * The interceptor walks the view hierarchy from the sandbox up to the root to
 * detect overlapping siblings and their descendants (including overflow, e.g.
 * a card with negative margin extending outside its parent). Custom drawing
 * order (React Native's `zIndex` via `ReactZIndexedViewGroup`) is handled
 * through reflection on the protected [ViewGroup.getChildDrawingOrder] and
 * `isChildrenDrawingOrderEnabled` methods.
 */
object SandboxTouchInterceptor {
    /** All registered sandbox views, held as weak references to avoid leaks. */
    private val sandboxViews = mutableSetOf<WeakReference<SandboxReactNativeView>>()

    /** The Activity whose Window.Callback we've wrapped. Tracked to re-install on recreation. */
    private var installedActivity: WeakReference<Activity>? = null

    /**
     * Register a sandbox view for touch interception. Called from
     * [SandboxReactNativeView.onAttachedToWindow]. Also installs the
     * Window.Callback wrapper on the hosting Activity if not already done.
     */
    fun register(view: SandboxReactNativeView) {
        sandboxViews.removeAll { it.get() == null }
        sandboxViews.add(WeakReference(view))

        val activity = getActivity(view) ?: return
        installIfNeeded(activity)
    }

    /**
     * Unregister a sandbox view. Called from
     * [SandboxReactNativeView.onDetachedFromWindow].
     *
     * Before unwrapping the Window.Callback, we verify that the current
     * callback is still the [SandboxWindowCallback] we installed. Another
     * library (analytics SDK, testing framework, etc.) may have wrapped it
     * again after us, in which case we leave the chain intact to avoid
     * breaking that wrapper's state.
     */
    fun unregister(view: SandboxReactNativeView) {
        sandboxViews.removeAll { it.get() == null || it.get() === view }

        // If no sandbox views remain, consider unwrapping. Only do so if the
        // current callback is exactly the SandboxWindowCallback we installed —
        // a third-party wrapper on top of ours must not be silently discarded.
        if (sandboxViews.none { it.get() != null }) {
            val activity = installedActivity?.get() ?: return
            val current = activity.window.callback
            if (current is SandboxWindowCallback) {
                activity.window.callback = current.delegate
                installedActivity = null
            }
            // If current is NOT our SandboxWindowCallback, another library has
            // wrapped on top of us. Leave the chain alone; our wrapper will
            // simply become a no-op once sandboxViews is empty.
        }
    }

    /**
     * Wrap the Activity's [Window.Callback] with our [SandboxWindowCallback]
     * if not already wrapped. Re-installs if the Activity has changed (e.g.
     * after a configuration change / Activity recreation).
     */
    private fun installIfNeeded(activity: Activity) {
        val currentActivity = installedActivity?.get()
        if (currentActivity === activity) return

        installedActivity = WeakReference(activity)

        val window = activity.window
        val originalCallback = window.callback
        // Guard against double-wrapping if called multiple times
        if (originalCallback is SandboxWindowCallback) return

        window.callback = SandboxWindowCallback(originalCallback)
    }

    /**
     * Custom [Window.Callback] that intercepts all touches landing within
     * sandbox bounds.
     *
     * ## Gesture tracking
     *
     * On [MotionEvent.ACTION_DOWN] (start of a new gesture), we determine
     * whether the touch lands in a sandbox and whether that sandbox is
     * obscured. The decision is stored in [activeGestureSandbox] and
     * [activeGestureObscured] so that all subsequent events in the same
     * gesture (MOVE, UP, CANCEL, POINTER_DOWN, POINTER_UP) follow the
     * same routing. This ensures a gesture can't switch targets mid-drag.
     *
     * ## Routing
     *
     * - **No sandbox hit**: Falls through to [delegate] (normal Android dispatch).
     * - **Sandbox hit, not obscured**: Routes directly to the sandbox via
     *   [SandboxReactNativeView.dispatchTouchEventToChild].
     * - **Sandbox hit, obscured**: Calls [redispatchWithHiddenSandbox] to
     *   deliver to the overlay while preventing Fabric tag collision.
     */
    private class SandboxWindowCallback(
        /** The original callback we wrapped. Exposed so [unregister] can restore it. */
        val delegate: Window.Callback,
    ) : Window.Callback by delegate {
        /** The sandbox handling the current gesture, or null if no sandbox is involved. */
        private var activeGestureSandbox: WeakReference<SandboxReactNativeView>? = null

        /** Whether the current gesture started on an obscured sandbox area. */
        private var activeGestureObscured = false

        override fun dispatchTouchEvent(event: MotionEvent?): Boolean {
            if (event == null) return delegate.dispatchTouchEvent(event)

            when (event.actionMasked) {
                // New gesture — determine routing for the entire gesture
                MotionEvent.ACTION_DOWN -> {
                    val result = findSandboxAndObscured(event.rawX, event.rawY)
                    if (result != null) {
                        val (sandbox, obscured) = result
                        activeGestureSandbox = WeakReference(sandbox)
                        activeGestureObscured = obscured
                        return if (obscured) {
                            redispatchWithHiddenSandbox(sandbox, event)
                        } else {
                            sandbox.dispatchTouchEventToChild(event)
                            true
                        }
                    }
                    activeGestureSandbox = null
                    activeGestureObscured = false
                }

                // Continuation / end of gesture — route same as ACTION_DOWN decided
                MotionEvent.ACTION_MOVE,
                MotionEvent.ACTION_UP,
                MotionEvent.ACTION_CANCEL,
                -> {
                    val sandbox = activeGestureSandbox?.get()
                    if (sandbox != null) {
                        val handled =
                            if (activeGestureObscured) {
                                redispatchWithHiddenSandbox(sandbox, event)
                            } else {
                                sandbox.dispatchTouchEventToChild(event)
                                true
                            }
                        // Clean up gesture state when the gesture ends
                        if (event.actionMasked == MotionEvent.ACTION_UP ||
                            event.actionMasked == MotionEvent.ACTION_CANCEL
                        ) {
                            activeGestureSandbox = null
                            activeGestureObscured = false
                        }
                        return handled
                    }
                }

                // Multi-touch — additional fingers follow the active gesture's routing.
                // ACTION_DOWN already decided which sandbox (or none) owns this gesture;
                // a second finger arriving mid-gesture inherits that decision so the
                // gesture can't switch targets. This is the correct semantic: the gesture
                // target is locked on the first finger down.
                MotionEvent.ACTION_POINTER_DOWN,
                MotionEvent.ACTION_POINTER_UP,
                -> {
                    val sandbox = activeGestureSandbox?.get()
                    if (sandbox != null) {
                        return if (activeGestureObscured) {
                            redispatchWithHiddenSandbox(sandbox, event)
                        } else {
                            sandbox.dispatchTouchEventToChild(event)
                            true
                        }
                    }
                }
            }

            // No sandbox involved — normal Android dispatch
            return delegate.dispatchTouchEvent(event)
        }

        /**
         * Handle touches that land in a sandbox's bounds but are obscured by
         * an overlay view.
         *
         * We can't just fall through to [delegate.dispatchTouchEvent] because
         * the host's [ReactSurfaceView] would still process the event through
         * Fabric's C++ touch handler, hitting the colliding tag. Instead, we
         * temporarily set the sandbox's children to [View.INVISIBLE] so the
         * host's Fabric renderer skips them during hit-testing, then dispatch
         * normally so the overlay receives the event. Visibility is restored
         * immediately — this is synchronous on the UI thread, so there's no
         * visual flicker.
         *
         * Why INVISIBLE and not GONE?
         * GONE triggers a layout pass (requestLayout) which is expensive and
         * can cause a brief visual glitch. INVISIBLE only affects drawing and
         * hit-testing — the view retains its measured size and position, so
         * no layout is invalidated. It also avoids sending spurious
         * accessibility events that GONE would trigger.
         *
         * Why not dispatch a CANCEL to the sandbox instead?
         * A synthetic CANCEL would require the sandbox's gesture recogniser to
         * already be tracking a gesture. On ACTION_DOWN there is no active
         * gesture to cancel, so a CANCEL event would be silently dropped and
         * the sandbox's Fabric renderer would still process the original DOWN.
         */
        private fun redispatchWithHiddenSandbox(
            sandbox: SandboxReactNativeView,
            event: MotionEvent,
        ): Boolean {
            // Save and hide each child's visibility
            val children = mutableListOf<Pair<View, Int>>()
            for (i in 0 until sandbox.childCount) {
                val child = sandbox.getChildAt(i)
                children.add(Pair(child, child.visibility))
                child.visibility = View.INVISIBLE
            }

            // Dispatch through normal path — overlay will receive the event,
            // Fabric won't see the sandbox's surface view
            val handled = delegate.dispatchTouchEvent(event)

            // Restore original visibility
            for ((child, originalVisibility) in children) {
                child.visibility = originalVisibility
            }

            return handled
        }
    }

    /**
     * Find a sandbox whose screen bounds contain the touch point.
     *
     * Iterates all registered sandbox views. For the first one whose bounds
     * contain the point, calls [isObscuredAt] to determine if an overlay is
     * drawn on top at that location.
     *
     * @return A pair of (sandbox, isObscured), or null if no sandbox contains
     *         the touch point.
     */
    private fun findSandboxAndObscured(
        rawX: Float,
        rawY: Float,
    ): Pair<SandboxReactNativeView, Boolean>? {
        val location = IntArray(2)
        val x = rawX.toInt()
        val y = rawY.toInt()

        for (ref in sandboxViews) {
            val sandbox = ref.get() ?: continue
            if (!sandbox.isAttachedToWindow || !sandbox.isShown) continue

            sandbox.getLocationOnScreen(location)
            val rect =
                Rect(
                    location[0],
                    location[1],
                    location[0] + sandbox.width,
                    location[1] + sandbox.height,
                )
            if (!rect.contains(x, y)) continue

            return Pair(sandbox, isObscuredAt(sandbox, x, y))
        }
        return null
    }

    /**
     * Determine if a view drawn above [target] in the z-order contains the
     * screen-coordinate point ([screenX], [screenY]).
     *
     * Walks from [target] up to the root of the view tree. At each
     * [ViewGroup] ancestor, examines all sibling views that are drawn after
     * (on top of) the branch containing [target]. A sibling "obscures" if:
     * 1. It is drawn after [target]'s branch ([isDrawnAfter])
     * 2. It is [View.VISIBLE]
     * 3. Its screen bounds contain the touch point, OR any of its descendants'
     *    screen bounds contain the point ([hasDescendantAt] — handles overflow)
     *
     * The walk continues up the tree because an obscuring view might be a
     * sibling of a grandparent, not just a direct sibling of the sandbox.
     */
    private fun isObscuredAt(
        target: View,
        screenX: Int,
        screenY: Int,
    ): Boolean {
        var child: View = target
        var parent = child.parent
        val siblingLoc = IntArray(2)

        while (parent is ViewGroup) {
            val group = parent
            val childIndex = group.indexOfChild(child)

            for (i in 0 until group.childCount) {
                if (i == childIndex) continue
                val sibling = group.getChildAt(i)
                if (!isDrawnAfter(group, i, childIndex)) continue
                if (sibling.visibility != View.VISIBLE) continue

                // Check the sibling's own bounds
                sibling.getLocationOnScreen(siblingLoc)
                val sibRect =
                    Rect(
                        siblingLoc[0],
                        siblingLoc[1],
                        siblingLoc[0] + sibling.width,
                        siblingLoc[1] + sibling.height,
                    )
                if (sibRect.contains(screenX, screenY)) return true

                // Check descendants — catches overflow (e.g. a card with
                // negative margin extending outside its parent's bounds)
                if (sibling is ViewGroup && hasDescendantAt(sibling, screenX, screenY)) {
                    return true
                }
            }

            // Move up one level in the tree
            child = group
            parent = group.parent
        }

        return false
    }

    /**
     * Recursively check if [viewGroup] has any visible descendant whose
     * screen bounds contain ([screenX], [screenY]).
     *
     * This is needed because Android allows children to render outside their
     * parent's bounds (unless `clipChildren` is set). A common case is a
     * React Native view with negative margin or absolute positioning that
     * overflows its container.
     */
    private fun hasDescendantAt(
        viewGroup: ViewGroup,
        screenX: Int,
        screenY: Int,
    ): Boolean {
        val loc = IntArray(2)
        for (i in 0 until viewGroup.childCount) {
            val child = viewGroup.getChildAt(i)
            if (child.visibility != View.VISIBLE) continue

            child.getLocationOnScreen(loc)
            val childRect =
                Rect(
                    loc[0],
                    loc[1],
                    loc[0] + child.width,
                    loc[1] + child.height,
                )
            if (childRect.contains(screenX, screenY)) return true
            if (child is ViewGroup && hasDescendantAt(child, screenX, screenY)) return true
        }
        return false
    }

    /**
     * Determine if the child at [candidateIndex] is drawn after (on top of)
     * the child at [referenceIndex] within [parent].
     *
     * By default, Android draws children in index order (higher index = on top).
     * When custom drawing order is enabled (e.g. React Native's zIndex),
     * [ViewGroup.getChildDrawingOrder] maps draw positions to child indices.
     * We iterate all draw positions to find where each child is actually drawn
     * and compare their positions.
     *
     * Falls back to natural index ordering if reflection fails.
     */
    private fun isDrawnAfter(
        parent: ViewGroup,
        candidateIndex: Int,
        referenceIndex: Int,
    ): Boolean {
        val customOrder =
            try {
                isChildrenDrawingOrderEnabledMethod?.invoke(parent) as? Boolean ?: false
            } catch (_: Exception) {
                false
            }

        if (!customOrder) return candidateIndex > referenceIndex

        val method = getChildDrawingOrderMethod ?: return candidateIndex > referenceIndex

        try {
            val count = parent.childCount
            var candidateDrawPos = candidateIndex
            var referenceDrawPos = referenceIndex

            for (drawPos in 0 until count) {
                val childIdx = method.invoke(parent, count, drawPos) as Int
                if (childIdx == candidateIndex) candidateDrawPos = drawPos
                if (childIdx == referenceIndex) referenceDrawPos = drawPos
            }

            return candidateDrawPos > referenceDrawPos
        } catch (_: Exception) {
            return candidateIndex > referenceIndex
        }
    }

    /**
     * Extract the hosting [Activity] from a view's Context chain.
     * Android wraps contexts (e.g. ThemedReactContext → ContextWrapper →
     * Activity), so we unwrap until we find the Activity.
     */
    private fun getActivity(view: SandboxReactNativeView): Activity? {
        var ctx = view.context
        while (ctx is android.content.ContextWrapper) {
            if (ctx is Activity) return ctx
            ctx = ctx.baseContext
        }
        return null
    }

    // ── Drawing order helpers ───────────────────────────────────────────────
    //
    // ViewGroup.isChildrenDrawingOrderEnabled() and getChildDrawingOrder()
    // are protected methods. React Native's ReactZIndexedViewGroup overrides
    // them to implement zIndex support. We use reflection (cached in lazy
    // vals so the Method lookup happens once) to access them.
    //
    // If reflection fails (future Android release, vendor fork, or ProGuard
    // stripping), we fall back to natural index order and emit a one-time
    // warning so silent regressions surface in production logs.

    private val isChildrenDrawingOrderEnabledMethod by lazy {
        try {
            ViewGroup::class.java.getDeclaredMethod("isChildrenDrawingOrderEnabled").also {
                it.isAccessible = true
            }
        } catch (e: Exception) {
            android.util.Log.w(
                "SandboxTouchInterceptor",
                "Reflection on ViewGroup.isChildrenDrawingOrderEnabled() failed — " +
                    "falling back to natural draw order. zIndex-based overlay detection may be inaccurate. " +
                    "Cause: ${e.message}",
            )
            null
        }
    }

    private val getChildDrawingOrderMethod by lazy {
        try {
            ViewGroup::class.java
                .getDeclaredMethod(
                    "getChildDrawingOrder",
                    Int::class.javaPrimitiveType,
                    Int::class.javaPrimitiveType,
                ).also { it.isAccessible = true }
        } catch (e: Exception) {
            android.util.Log.w(
                "SandboxTouchInterceptor",
                "Reflection on ViewGroup.getChildDrawingOrder() failed — " +
                    "falling back to natural draw order. zIndex-based overlay detection may be inaccurate. " +
                    "Cause: ${e.message}",
            )
            null
        }
    }
}
