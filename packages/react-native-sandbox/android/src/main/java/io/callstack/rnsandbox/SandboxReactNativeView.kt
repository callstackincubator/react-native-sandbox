package io.callstack.rnsandbox

import android.content.Context
import android.os.Bundle
import android.view.MotionEvent
import android.widget.FrameLayout
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event

class SandboxReactNativeView(
    context: Context,
) : FrameLayout(context) {
    var delegate: SandboxReactNativeDelegate? = null
    var pendingComponentName: String? = null
    var pendingInitialProperties: Bundle? = null
    var pendingLaunchOptions: Bundle? = null
    internal var loadScheduled: Boolean = false
    internal var needsLoad: Boolean = false
    internal var onAttachLoadCallback: (() -> Unit)? = null

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        SandboxTouchInterceptor.register(this)
        if (needsLoad && childCount == 0) {
            onAttachLoadCallback?.invoke()
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        SandboxTouchInterceptor.unregister(this)
    }

    /**
     * Forward a touch event directly to the sandbox's child surface view,
     * bypassing the host's ReactSurfaceView dispatch entirely.
     * Called by [SandboxTouchInterceptor] when a touch lands inside this sandbox.
     */
    fun dispatchTouchEventToChild(ev: MotionEvent) {
        if (childCount > 0) {
            val child = getChildAt(0)

            // Convert screen-absolute coordinates to sandbox-local coordinates.
            // The MotionEvent from the Window callback carries raw screen coords
            // (ev.rawX/rawY), but dispatchTouchEvent on a child expects coords
            // relative to the child's top-left corner. We get our screen position
            // and subtract it from the raw coords to produce the local offset.
            val loc = IntArray(2)
            getLocationOnScreen(loc)
            val offsetX = ev.rawX - loc[0]
            val offsetY = ev.rawY - loc[1]

            // Create a copy of the original event rather than mutating it —
            // the original may still be referenced by other parts of the
            // Android dispatch pipeline.
            val localEvent = MotionEvent.obtain(ev)
            localEvent.setLocation(offsetX, offsetY)
            child?.dispatchTouchEvent(localEvent)
            localEvent.recycle()
        }
    }

    /**
     * Fabric manages our dimensions but not our children's (they come from a
     * separate ReactHost).  Force children to fill the space Fabric gave us.
     */
    override fun onLayout(
        changed: Boolean,
        left: Int,
        top: Int,
        right: Int,
        bottom: Int,
    ) {
        super.onLayout(changed, left, top, right, bottom)
        val w = right - left
        val h = bottom - top
        for (i in 0 until childCount) {
            getChildAt(i).layout(0, 0, w, h)
        }
    }

    override fun requestLayout() {
        super.requestLayout()
        post {
            measure(
                MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY),
            )
            layout(left, top, right, bottom)
        }
    }

    fun emitOnMessage(data: WritableMap) {
        val reactContext = context as? ReactContext ?: return
        val surfaceId = UIManagerHelper.getSurfaceId(reactContext)
        val eventDispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)
        eventDispatcher?.dispatchEvent(OnMessageEvent(surfaceId, id, data))
    }

    fun emitOnError(
        name: String,
        message: String,
        stack: String? = null,
        isFatal: Boolean = false,
    ) {
        val reactContext = context as? ReactContext ?: return
        val surfaceId = UIManagerHelper.getSurfaceId(reactContext)
        val eventDispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)
        val payload =
            Arguments.createMap().apply {
                putString("name", name)
                putString("message", message)
                putString("stack", stack ?: "")
                putBoolean("isFatal", isFatal)
            }
        eventDispatcher?.dispatchEvent(OnErrorEvent(surfaceId, id, payload))
    }

    inner class OnMessageEvent(
        surfaceId: Int,
        viewId: Int,
        private val payload: WritableMap,
    ) : Event<OnMessageEvent>(surfaceId, viewId) {
        override fun getEventName() = "topMessage"

        override fun getEventData() = payload
    }

    inner class OnErrorEvent(
        surfaceId: Int,
        viewId: Int,
        private val payload: WritableMap,
    ) : Event<OnErrorEvent>(surfaceId, viewId) {
        override fun getEventName() = "topError"

        override fun getEventData() = payload
    }
}
