package io.callstack.rnsandbox

import android.util.Log

/**
 * Thread-safe singleton registry for managing sandbox delegates.
 * Mirrors the C++ SandboxRegistry for cross-sandbox communication.
 */
object SandboxRegistry {
    private const val TAG = "SandboxRegistry"
    private val lock = Any()
    private val sandboxRegistry = mutableMapOf<String, SandboxReactNativeDelegate>()
    private val allowedOriginsMap = mutableMapOf<String, Set<String>>()

    fun register(
        origin: String,
        delegate: SandboxReactNativeDelegate,
        allowedOrigins: Set<String>,
    ) {
        if (origin.isEmpty()) return

        synchronized(lock) {
            if (sandboxRegistry.containsKey(origin)) {
                Log.w(TAG, "Overwriting existing sandbox with origin: $origin, allowedOrigins=$allowedOrigins")
            } else {
                Log.d(TAG, "Registering sandbox origin: $origin, allowedOrigins=$allowedOrigins")
            }
            sandboxRegistry[origin] = delegate
            allowedOriginsMap[origin] = allowedOrigins
        }
    }

    fun unregister(origin: String) {
        if (origin.isEmpty()) return

        synchronized(lock) {
            sandboxRegistry.remove(origin)
            allowedOriginsMap.remove(origin)
        }
    }

    fun find(origin: String): SandboxReactNativeDelegate? {
        if (origin.isEmpty()) return null

        synchronized(lock) {
            return sandboxRegistry[origin]
        }
    }

    fun isPermittedFrom(
        sourceOrigin: String,
        targetOrigin: String,
    ): Boolean {
        if (sourceOrigin.isEmpty() || targetOrigin.isEmpty()) return false

        synchronized(lock) {
            val origins = allowedOriginsMap[sourceOrigin] ?: return false
            val permitted = origins.contains(targetOrigin)
            if (!permitted) {
                Log.w(TAG, "isPermittedFrom($sourceOrigin -> $targetOrigin): denied. allowedOrigins[$sourceOrigin]=$origins")
            }
            return permitted
        }
    }

    fun reset() {
        synchronized(lock) {
            sandboxRegistry.clear()
            allowedOriginsMap.clear()
        }
    }
}
