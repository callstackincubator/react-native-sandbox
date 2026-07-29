package io.callstack.rnsandbox

import com.facebook.react.ReactPackage
import expo.modules.adapters.react.ModuleRegistryAdapter
import expo.modules.adapters.react.ReactAdapterPackage
import expo.modules.adapters.react.ReactModuleRegistryProvider
import expo.modules.kotlin.ExpoModulesHelper

/**
 * Wires Expo modules into a sandbox React Native host.
 *
 * Each sandbox already wraps its ReactApplicationContext with SandboxContextWrapper,
 * which overrides getFilesDir(), getCacheDir(), and getSharedPreferences() to return
 * origin-namespaced paths. Since Expo's AppContext receives this wrapped context, all
 * Expo modules (FileSystem, SecureStore, etc.) automatically operate in scoped
 * directories without additional AppContext configuration.
 */
internal object ExpoIntegration {
    /**
     * Returns the ReactPackage instances required to expose Expo modules inside a
     * sandbox. Include the result in the sandbox's package list when
     * BuildConfig.HAS_EXPO_MODULES is true.
     */
    fun createPackages(): List<ReactPackage> {
        val registryProvider = ReactModuleRegistryProvider(listOf(ReactAdapterPackage()), null)
        val modulesProvider = ExpoModulesHelper.modulesProvider
        return listOf(ModuleRegistryAdapter(registryProvider, modulesProvider))
    }
}
