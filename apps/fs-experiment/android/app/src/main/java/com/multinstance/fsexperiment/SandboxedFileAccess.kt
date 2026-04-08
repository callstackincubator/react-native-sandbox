package com.multinstance.fsexperiment

import android.os.StatFs
import android.util.Base64
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import io.callstack.rnsandbox.SandboxAwareModule
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Sandboxed FileAccess — jails all file paths to a per-origin directory.
 *
 * Mirrors the iOS SandboxedFileAccess.mm implementation. Implements the
 * react-native-file-access module interface so JS code works transparently.
 */
@ReactModule(name = SandboxedFileAccess.MODULE_NAME)
class SandboxedFileAccess(
    private val reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext), SandboxAwareModule {

    companion object {
        const val MODULE_NAME = "SandboxedFileAccess"
        private const val TAG = "SandboxedFileAccess"
    }

    private val executor = Executors.newSingleThreadExecutor()

    private var sandboxRoot: String = ""
    private var documentsDir: String = ""
    private var cachesDir: String = ""
    @Volatile private var configured = false

    override fun getName(): String = MODULE_NAME

    override fun configureSandbox(origin: String, requestedName: String, resolvedName: String) {
        Log.d(TAG, "Configuring for origin '$origin'")
        val base = File(reactContext.filesDir, "Sandboxes/$origin")
        sandboxRoot = base.absolutePath
        documentsDir = File(base, "Documents").absolutePath
        cachesDir = File(base, "Caches").absolutePath

        listOf(documentsDir, cachesDir).forEach { File(it).mkdirs() }
        configured = true
    }

    override fun invalidate() {
        executor.shutdown()
        try {
            executor.awaitTermination(2, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
            executor.shutdownNow()
        }
        configured = false
        super.invalidate()
    }

    private fun sandboxedPath(path: String, promise: Promise): String? {
        if (!configured) {
            promise.reject("EPERM", "SandboxedFileAccess: sandbox not configured.")
            return null
        }
        val resolved = if (path.startsWith("/")) {
            File(path).canonicalPath
        } else {
            File(documentsDir, path).canonicalPath
        }
        if (resolved.startsWith(sandboxRoot)) return resolved
        promise.reject("EPERM", "Path '$path' is outside the sandbox. Allowed root: $sandboxRoot")
        return null
    }

    override fun getConstants(): Map<String, Any?> {
        if (!configured) return mapOf(
            "CacheDir" to "", "DocumentDir" to "", "MainBundleDir" to "",
        )
        return mapOf(
            "CacheDir" to cachesDir,
            "DocumentDir" to documentsDir,
            "MainBundleDir" to documentsDir,
        )
    }

    @ReactMethod
    fun writeFile(path: String, data: String, encoding: String, promise: Promise) {
        val safePath = sandboxedPath(path, promise) ?: return
        executor.execute {
            try {
                File(safePath).parentFile?.mkdirs()
                if (encoding == "base64") {
                    val decoded = Base64.decode(data, Base64.DEFAULT)
                    FileOutputStream(safePath).use { it.write(decoded) }
                } else {
                    File(safePath).writeText(data, Charsets.UTF_8)
                }
                promise.resolve(null)
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to write to '$path': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun readFile(path: String, encoding: String, promise: Promise) {
        val safePath = sandboxedPath(path, promise) ?: return
        executor.execute {
            try {
                val file = File(safePath)
                if (!file.exists()) {
                    promise.reject("ERR", "No such file '$path'")
                    return@execute
                }
                if (encoding == "base64") {
                    val bytes = file.readBytes()
                    promise.resolve(Base64.encodeToString(bytes, Base64.NO_WRAP))
                } else {
                    promise.resolve(file.readText(Charsets.UTF_8))
                }
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to read '$path': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun readFileChunk(path: String, offset: Double, length: Double, encoding: String, promise: Promise) {
        val safePath = sandboxedPath(path, promise) ?: return
        executor.execute {
            try {
                RandomAccessFile(safePath, "r").use { raf ->
                    raf.seek(offset.toLong())
                    val buf = ByteArray(length.toInt())
                    val bytesRead = raf.read(buf)
                    if (bytesRead <= 0) {
                        promise.resolve("")
                        return@execute
                    }
                    val actual = buf.copyOf(bytesRead)
                    if (encoding == "base64") {
                        promise.resolve(Base64.encodeToString(actual, Base64.NO_WRAP))
                    } else {
                        promise.resolve(String(actual, Charsets.UTF_8))
                    }
                }
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to read chunk '$path': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun appendFile(path: String, data: String, encoding: String, promise: Promise) {
        val safePath = sandboxedPath(path, promise) ?: return
        executor.execute {
            try {
                val bytes = if (encoding == "base64") {
                    Base64.decode(data, Base64.DEFAULT)
                } else {
                    data.toByteArray(Charsets.UTF_8)
                }
                FileOutputStream(safePath, true).use { it.write(bytes) }
                promise.resolve(null)
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to append to '$path': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun exists(path: String, promise: Promise) {
        val safePath = sandboxedPath(path, promise) ?: return
        executor.execute { promise.resolve(File(safePath).exists()) }
    }

    @ReactMethod
    fun isDir(path: String, promise: Promise) {
        val safePath = sandboxedPath(path, promise) ?: return
        executor.execute {
            val f = File(safePath)
            promise.resolve(f.exists() && f.isDirectory)
        }
    }

    @ReactMethod
    fun ls(path: String, promise: Promise) {
        val safePath = sandboxedPath(path, promise) ?: return
        executor.execute {
            try {
                val dir = File(safePath)
                val result = Arguments.createArray()
                dir.listFiles()?.forEach { result.pushString(it.name) }
                promise.resolve(result)
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to list '$path': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun mkdir(path: String, promise: Promise) {
        val safePath = sandboxedPath(path, promise) ?: return
        executor.execute {
            try {
                File(safePath).mkdirs()
                promise.resolve(safePath)
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to mkdir '$path': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun cp(source: String, target: String, promise: Promise) {
        val src = sandboxedPath(source, promise) ?: return
        val dst = sandboxedPath(target, promise) ?: return
        executor.execute {
            try {
                File(dst).parentFile?.mkdirs()
                File(src).copyTo(File(dst), overwrite = true)
                promise.resolve(null)
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to copy '$source' to '$target': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun mv(source: String, target: String, promise: Promise) {
        val src = sandboxedPath(source, promise) ?: return
        val dst = sandboxedPath(target, promise) ?: return
        executor.execute {
            try {
                File(dst).parentFile?.mkdirs()
                val srcFile = File(src)
                val dstFile = File(dst)
                dstFile.delete()
                if (!srcFile.renameTo(dstFile)) {
                    srcFile.copyTo(dstFile, overwrite = true)
                    srcFile.delete()
                }
                promise.resolve(null)
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to move '$source' to '$target': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun unlink(path: String, promise: Promise) {
        val safePath = sandboxedPath(path, promise) ?: return
        executor.execute {
            try {
                val file = File(safePath)
                if (file.isDirectory) file.deleteRecursively() else file.delete()
                promise.resolve(null)
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to unlink '$path': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun stat(path: String, promise: Promise) {
        val safePath = sandboxedPath(path, promise) ?: return
        executor.execute {
            try {
                val file = File(safePath)
                if (!file.exists()) {
                    promise.reject("ERR", "No such file '$path'")
                    return@execute
                }
                val result = Arguments.createMap()
                result.putString("filename", file.name)
                result.putDouble("lastModified", file.lastModified().toDouble())
                result.putString("path", safePath)
                result.putDouble("size", file.length().toDouble())
                result.putString("type", if (file.isDirectory) "directory" else "file")
                promise.resolve(result)
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to stat '$path': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun statDir(path: String, promise: Promise) {
        val safePath = sandboxedPath(path, promise) ?: return
        executor.execute {
            try {
                val dir = File(safePath)
                val results = Arguments.createArray()
                dir.listFiles()?.forEach { file ->
                    val item = Arguments.createMap()
                    item.putString("filename", file.name)
                    item.putDouble("lastModified", file.lastModified().toDouble())
                    item.putString("path", file.absolutePath)
                    item.putDouble("size", file.length().toDouble())
                    item.putString("type", if (file.isDirectory) "directory" else "file")
                    results.pushMap(item)
                }
                promise.resolve(results)
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to statDir '$path': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun hash(path: String, algorithm: String, promise: Promise) {
        val safePath = sandboxedPath(path, promise) ?: return
        executor.execute {
            try {
                val algoMap = mapOf(
                    "MD5" to "MD5", "SHA-1" to "SHA-1", "SHA-256" to "SHA-256", "SHA-512" to "SHA-512"
                )
                val javaAlgo = algoMap[algorithm]
                if (javaAlgo == null) {
                    promise.reject("ERR", "Unknown algorithm '$algorithm'")
                    return@execute
                }
                val md = MessageDigest.getInstance(javaAlgo)
                FileInputStream(safePath).use { fis ->
                    val buf = ByteArray(8192)
                    var len: Int
                    while (fis.read(buf).also { len = it } != -1) md.update(buf, 0, len)
                }
                promise.resolve(md.digest().joinToString("") { "%02x".format(it) })
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to hash '$path': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun concatFiles(source: String, target: String, promise: Promise) {
        val src = sandboxedPath(source, promise) ?: return
        val dst = sandboxedPath(target, promise) ?: return
        executor.execute {
            try {
                var totalBytes = 0L
                FileInputStream(src).use { input ->
                    FileOutputStream(dst, true).use { output ->
                        val buf = ByteArray(8192)
                        var len: Int
                        while (input.read(buf).also { len = it } != -1) {
                            output.write(buf, 0, len)
                            totalBytes += len
                        }
                    }
                }
                promise.resolve(totalBytes.toDouble())
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to concat '$source' to '$target': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun df(promise: Promise) {
        if (!configured) {
            promise.reject("EPERM", "SandboxedFileAccess: sandbox not configured.")
            return
        }
        executor.execute {
            try {
                val stat = StatFs(sandboxRoot)
                val result = Arguments.createMap()
                result.putDouble("internal_free", stat.availableBytes.toDouble())
                result.putDouble("internal_total", stat.totalBytes.toDouble())
                promise.resolve(result)
            } catch (e: Exception) {
                promise.reject("ERR", "Failed to stat filesystem: ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun fetch(requestId: Double, resource: String, init: ReadableMap) {
        Log.w(TAG, "fetch is not available in sandboxed mode")
    }

    @ReactMethod
    fun cancelFetch(requestId: Double, promise: Promise) {
        promise.resolve(null)
    }

    @ReactMethod
    fun cpAsset(asset: String, target: String, type: String, promise: Promise) {
        promise.reject("EPERM", "cpAsset is not available in sandboxed mode")
    }

    @ReactMethod
    fun cpExternal(source: String, targetName: String, dir: String, promise: Promise) {
        promise.reject("EPERM", "cpExternal is not available in sandboxed mode")
    }

    @ReactMethod
    fun getAppGroupDir(groupName: String, promise: Promise) {
        promise.reject("EPERM", "getAppGroupDir is not available in sandboxed mode")
    }

    @ReactMethod
    fun unzip(source: String, target: String, promise: Promise) {
        promise.reject("EPERM", "unzip is not available in sandboxed mode")
    }

    @ReactMethod
    fun addListener(eventName: String) = Unit

    @ReactMethod
    fun removeListeners(count: Double) = Unit
}
