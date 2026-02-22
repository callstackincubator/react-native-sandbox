package io.callstack.rnsandbox

import android.content.Context
import android.os.Bundle
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
    var loadScheduled: Boolean = false
    var needsLoad: Boolean = false
    var onAttachLoadCallback: (() -> Unit)? = null

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (needsLoad && childCount == 0) {
            onAttachLoadCallback?.invoke()
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
