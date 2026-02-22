package io.callstack.rnsandbox

import com.facebook.jni.HybridData
import com.facebook.react.runtime.BindingsInstaller
import com.facebook.soloader.SoLoader

class SandboxBindingsInstaller private constructor(
    hybridData: HybridData,
    private val delegate: SandboxReactNativeDelegate,
) : BindingsInstaller(hybridData) {
    companion object {
        init {
            SoLoader.loadLibrary("rnsandbox")
        }

        fun create(delegate: SandboxReactNativeDelegate): SandboxBindingsInstaller {
            val hybridData = initHybrid(delegate)
            return SandboxBindingsInstaller(hybridData, delegate)
        }

        @JvmStatic
        private external fun initHybrid(delegate: Any): HybridData
    }

    @Suppress("unused")
    fun onJSIBindingsInstalled(stateHandle: Long) {
        delegate.onJSIBindingsInstalled(stateHandle)
    }
}
