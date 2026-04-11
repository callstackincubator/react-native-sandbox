package com.multinstance.fsexperiment

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

/**
 * ReactPackage providing sandboxed module implementations for the fs-experiment app.
 *
 * Registered via SandboxReactNativeDelegate.registerSubstitutionPackages() in
 * MainApplication.onCreate() so the sandbox's FilteredReactPackage can resolve
 * substitution targets.
 */
class SandboxedModulesPackage : BaseReactPackage() {

    override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
        return when (name) {
            SandboxedFileAccess.MODULE_NAME -> SandboxedFileAccess(reactContext)
            SandboxedAsyncStorage.MODULE_NAME -> SandboxedAsyncStorage(reactContext)
            else -> null
        }
    }

    override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
        return ReactModuleInfoProvider {
            mapOf(
                SandboxedFileAccess.MODULE_NAME to ReactModuleInfo(
                    SandboxedFileAccess.MODULE_NAME,
                    SandboxedFileAccess.MODULE_NAME,
                    false, false, false, false, false,
                ),
                SandboxedAsyncStorage.MODULE_NAME to ReactModuleInfo(
                    SandboxedAsyncStorage.MODULE_NAME,
                    SandboxedAsyncStorage.MODULE_NAME,
                    false, false, false, false, false,
                ),
            )
        }
    }

    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> =
        emptyList()
}
