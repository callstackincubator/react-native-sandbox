package io.callstack.rnsandbox

import android.os.Bundle
import android.widget.FrameLayout
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Dynamic
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableType
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.SandboxReactNativeViewManagerDelegate
import com.facebook.react.viewmanagers.SandboxReactNativeViewManagerInterface

@ReactModule(name = SandboxReactNativeViewManager.REACT_CLASS)
class SandboxReactNativeViewManager :
    ViewGroupManager<SandboxReactNativeView>(),
    SandboxReactNativeViewManagerInterface<SandboxReactNativeView> {
    companion object {
        const val REACT_CLASS = "SandboxReactNativeView"
    }

    private val mDelegate = SandboxReactNativeViewManagerDelegate(this)

    override fun getDelegate(): ViewManagerDelegate<SandboxReactNativeView> = mDelegate

    override fun getName(): String = REACT_CLASS

    override fun createViewInstance(context: ThemedReactContext): SandboxReactNativeView {
        val view = SandboxReactNativeView(context)
        view.delegate =
            SandboxReactNativeDelegate(context).apply {
                sandboxView = view
            }
        view.onAttachLoadCallback = { loadReactNativeView(view) }
        return view
    }

    override fun onDropViewInstance(view: SandboxReactNativeView) {
        super.onDropViewInstance(view)
        view.delegate?.destroy()
        view.delegate = null
    }

    @ReactProp(name = "origin")
    override fun setOrigin(
        view: SandboxReactNativeView,
        value: String?,
    ) {
        view.delegate?.origin = value ?: ""
    }

    @ReactProp(name = "componentName")
    override fun setComponentName(
        view: SandboxReactNativeView,
        value: String?,
    ) {
        if (view.pendingComponentName == value) return
        view.pendingComponentName = value
        scheduleLoad(view)
    }

    @ReactProp(name = "jsBundleSource")
    override fun setJsBundleSource(
        view: SandboxReactNativeView,
        value: String?,
    ) {
        val newValue = value ?: ""
        val delegate = view.delegate ?: return
        if (delegate.jsBundleSource == newValue) return
        delegate.jsBundleSource = newValue
        if (view.childCount > 0 && delegate.reloadWithNewBundleSource()) return
        scheduleLoad(view)
    }

    @ReactProp(name = "initialProperties")
    override fun setInitialProperties(
        view: SandboxReactNativeView,
        value: Dynamic,
    ) {
        val newBundle = dynamicToBundle(value)
        if (bundlesEqual(view.pendingInitialProperties, newBundle)) return
        view.pendingInitialProperties = newBundle
        if (view.childCount > 0) {
            scheduleLoad(view)
        }
    }

    @ReactProp(name = "launchOptions")
    override fun setLaunchOptions(
        view: SandboxReactNativeView,
        value: Dynamic,
    ) {
        val newBundle = dynamicToBundle(value)
        if (bundlesEqual(view.pendingLaunchOptions, newBundle)) return
        view.pendingLaunchOptions = newBundle
        if (view.childCount > 0) {
            scheduleLoad(view)
        }
    }

    @ReactProp(name = "allowedTurboModules")
    override fun setAllowedTurboModules(
        view: SandboxReactNativeView,
        value: ReadableArray?,
    ) {
        val modules = mutableSetOf<String>()
        value?.let {
            for (i in 0 until it.size()) {
                it.getString(i)?.let { name -> modules.add(name) }
            }
        }
        view.delegate?.allowedTurboModules = modules
    }

    @ReactProp(name = "allowedOrigins")
    override fun setAllowedOrigins(
        view: SandboxReactNativeView,
        value: ReadableArray?,
    ) {
        val origins = mutableSetOf<String>()
        value?.let {
            for (i in 0 until it.size()) {
                it.getString(i)?.let { name -> origins.add(name) }
            }
        }
        view.delegate?.allowedOrigins = origins
    }

    @ReactProp(name = "hasOnMessageHandler")
    override fun setHasOnMessageHandler(
        view: SandboxReactNativeView,
        value: Boolean,
    ) {
        view.delegate?.hasOnMessageHandler = value
    }

    @ReactProp(name = "hasOnErrorHandler")
    override fun setHasOnErrorHandler(
        view: SandboxReactNativeView,
        value: Boolean,
    ) {
        view.delegate?.hasOnErrorHandler = value
    }

    override fun postMessage(
        view: SandboxReactNativeView,
        message: String,
    ) {
        view.delegate?.postMessage(message)
    }

    override fun receiveCommand(
        root: SandboxReactNativeView,
        commandId: String,
        args: ReadableArray?,
    ) {
        mDelegate.receiveCommand(root, commandId, args)
    }

    private fun scheduleLoad(view: SandboxReactNativeView) {
        view.needsLoad = true
        if (view.loadScheduled) return
        view.loadScheduled = true

        val posted =
            view.post {
                view.loadScheduled = false
                loadReactNativeView(view)
            }
        if (!posted) {
            view.loadScheduled = false
        }
    }

    private fun loadReactNativeView(view: SandboxReactNativeView) {
        if (!view.needsLoad) return

        val componentName = view.pendingComponentName
        val delegate = view.delegate

        if (componentName.isNullOrEmpty() || delegate == null || delegate.jsBundleSource.isEmpty()) {
            return
        }

        view.needsLoad = false
        view.removeAllViews()

        val rnView =
            delegate.loadReactNativeView(
                componentName = componentName,
                initialProperties = view.pendingInitialProperties,
                launchOptions = view.pendingLaunchOptions,
            ) ?: return

        view.addView(
            rnView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
    }

    private fun dynamicToBundle(dynamic: Dynamic): Bundle? {
        if (dynamic.isNull || dynamic.type != ReadableType.Map) return null
        return Arguments.toBundle(dynamic.asMap())
    }

    private fun bundlesEqual(
        a: Bundle?,
        b: Bundle?,
    ): Boolean {
        if (a === b) return true
        if (a == null || b == null) return false
        if (a.keySet() != b.keySet()) return false
        return a.keySet().all { key ->
            deepEquals(a.get(key), b.get(key))
        }
    }

    private fun deepEquals(
        a: Any?,
        b: Any?,
    ): Boolean {
        if (a === b) return true
        if (a == null || b == null) return false
        if (a is Bundle && b is Bundle) return bundlesEqual(a, b)
        if (a is ArrayList<*> && b is ArrayList<*>) {
            if (a.size != b.size) return false
            return a.indices.all { deepEquals(a[it], b[it]) }
        }
        return a == b
    }
}
