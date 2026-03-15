package io.callstack.rnsandbox

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

class SandboxReactNativePackage : BaseReactPackage() {
    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> =
        listOf(SandboxReactNativeViewManager())

    override fun getModule(
        name: String,
        reactContext: ReactApplicationContext,
    ): NativeModule? = null

    override fun getReactModuleInfoProvider(): ReactModuleInfoProvider =
        ReactModuleInfoProvider {
            mapOf(
                SandboxReactNativeViewManager.REACT_CLASS to
                    ReactModuleInfo(
                        name = SandboxReactNativeViewManager.REACT_CLASS,
                        className = SandboxReactNativeViewManager.REACT_CLASS,
                        canOverrideExistingModule = false,
                        needsEagerInit = false,
                        isCxxModule = false,
                        isTurboModule = true,
                    ),
            )
        }
}
