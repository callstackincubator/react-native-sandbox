package io.callstack.rnsandbox

import com.facebook.react.ReactPackage
import expo.modules.kotlin.ExpoModulesPackage

internal object ExpoIntegration {
    fun createPackages(): List<ReactPackage> = listOf(ExpoModulesPackage())
}
