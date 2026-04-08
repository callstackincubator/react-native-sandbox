package com.multinstance.fsexperiment

import android.util.Base64
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
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
 * Sandboxed RNFSManager — jails all file paths to a per-origin directory.
 *
 * Mirrors the iOS SandboxedRNFSManager.mm implementation. Every path argument
 * is validated against the sandbox root. Directory constants exposed to JS
 * (RNFSDocumentDirectoryPath, etc.) are overridden to point into the sandbox.
 */
@ReactModule(name = SandboxedRNFSManager.MODULE_NAME)
class SandboxedRNFSManager(
    private val reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext), SandboxAwareModule {

    companion object {
        const val MODULE_NAME = "SandboxedRNFSManager"
        private const val TAG = "SandboxedRNFSManager"
    }

    private val executor = Executors.newSingleThreadExecutor()

    private var sandboxRoot: String = ""
    private var documentsDir: String = ""
    private var cachesDir: String = ""
    private var tempDir: String = ""
    @Volatile private var configured = false

    override fun getName(): String = MODULE_NAME

    override fun configureSandbox(origin: String, requestedName: String, resolvedName: String) {
        Log.d(TAG, "Configuring for origin '$origin'")
        val base = File(reactContext.filesDir, "Sandboxes/$origin")
        sandboxRoot = base.absolutePath
        documentsDir = File(base, "Documents").absolutePath
        cachesDir = File(base, "Caches").absolutePath
        tempDir = File(base, "tmp").absolutePath

        listOf(documentsDir, cachesDir, tempDir).forEach { File(it).mkdirs() }
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
            promise.reject("EPERM", "SandboxedRNFSManager: sandbox not configured.")
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
        if (!configured) return emptyMap()
        return mapOf(
            "RNFSMainBundlePath" to documentsDir,
            "RNFSCachesDirectoryPath" to cachesDir,
            "RNFSDocumentDirectoryPath" to documentsDir,
            "RNFSExternalDirectoryPath" to null,
            "RNFSExternalStorageDirectoryPath" to null,
            "RNFSExternalCachesDirectoryPath" to null,
            "RNFSDownloadDirectoryPath" to null,
            "RNFSTemporaryDirectoryPath" to tempDir,
            "RNFSLibraryDirectoryPath" to null,
            "RNFSPicturesDirectoryPath" to null,
            "RNFSFileTypeRegular" to "NSFileTypeRegular",
            "RNFSFileTypeDirectory" to "NSFileTypeDirectory",
        )
    }

    @ReactMethod
    fun writeFile(filepath: String, base64Content: String, options: ReadableMap?, promise: Promise) {
        val path = sandboxedPath(filepath, promise) ?: return
        executor.execute {
            try {
                val data = Base64.decode(base64Content, Base64.DEFAULT)
                File(path).parentFile?.mkdirs()
                FileOutputStream(path).use { it.write(data) }
                promise.resolve(null)
            } catch (e: Exception) {
                promise.reject("ENOENT", "Could not write to '$path': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun readFile(filepath: String, promise: Promise) {
        val path = sandboxedPath(filepath, promise) ?: return
        executor.execute {
            try {
                val file = File(path)
                if (!file.exists()) {
                    promise.reject("ENOENT", "No such file '$path'")
                    return@execute
                }
                val data = file.readBytes()
                promise.resolve(Base64.encodeToString(data, Base64.NO_WRAP))
            } catch (e: Exception) {
                promise.reject("ENOENT", "Could not read '$path': ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun readDir(dirPath: String, promise: Promise) {
        val path = sandboxedPath(dirPath, promise) ?: return
        executor.execute {
            try {
                val dir = File(path)
                if (!dir.exists() || !dir.isDirectory) {
                    promise.reject("ENOENT", "No such directory '$path'")
                    return@execute
                }
                val result = Arguments.createArray()
                dir.listFiles()?.forEach { file ->
                    val item = Arguments.createMap()
                    item.putDouble("ctime", file.lastModified() / 1000.0)
                    item.putDouble("mtime", file.lastModified() / 1000.0)
                    item.putString("name", file.name)
                    item.putString("path", file.absolutePath)
                    item.putDouble("size", file.length().toDouble())
                    item.putString("type", if (file.isDirectory) "NSFileTypeDirectory" else "NSFileTypeRegular")
                    result.pushMap(item)
                }
                promise.resolve(result)
            } catch (e: Exception) {
                promise.reject("ENOENT", e.message, e)
            }
        }
    }

    @ReactMethod
    fun exists(filepath: String, promise: Promise) {
        val path = sandboxedPath(filepath, promise) ?: return
        executor.execute { promise.resolve(File(path).exists()) }
    }

    @ReactMethod
    fun stat(filepath: String, promise: Promise) {
        val path = sandboxedPath(filepath, promise) ?: return
        executor.execute {
            try {
                val file = File(path)
                if (!file.exists()) {
                    promise.reject("ENOENT", "No such file '$path'")
                    return@execute
                }
                val result = Arguments.createMap()
                result.putDouble("ctime", file.lastModified() / 1000.0)
                result.putDouble("mtime", file.lastModified() / 1000.0)
                result.putDouble("size", file.length().toDouble())
                result.putString("type", if (file.isDirectory) "NSFileTypeDirectory" else "NSFileTypeRegular")
                result.putInt("mode", 0)
                promise.resolve(result)
            } catch (e: Exception) {
                promise.reject("ENOENT", e.message, e)
            }
        }
    }

    @ReactMethod
    fun unlink(filepath: String, promise: Promise) {
        val path = sandboxedPath(filepath, promise) ?: return
        executor.execute {
            try {
                val file = File(path)
                if (file.isDirectory) {
                    file.deleteRecursively()
                } else {
                    file.delete()
                }
                promise.resolve(null)
            } catch (e: Exception) {
                promise.reject("ENOENT", e.message, e)
            }
        }
    }

    @ReactMethod
    fun mkdir(filepath: String, options: ReadableMap?, promise: Promise) {
        val path = sandboxedPath(filepath, promise) ?: return
        executor.execute {
            try {
                File(path).mkdirs()
                promise.resolve(null)
            } catch (e: Exception) {
                promise.reject("ENOENT", e.message, e)
            }
        }
    }

    @ReactMethod
    fun moveFile(filepath: String, destPath: String, options: ReadableMap?, promise: Promise) {
        val src = sandboxedPath(filepath, promise) ?: return
        val dst = sandboxedPath(destPath, promise) ?: return
        executor.execute {
            try {
                val srcFile = File(src)
                val dstFile = File(dst)
                dstFile.parentFile?.mkdirs()
                if (!srcFile.renameTo(dstFile)) {
                    srcFile.copyTo(dstFile, overwrite = true)
                    srcFile.delete()
                }
                promise.resolve(null)
            } catch (e: Exception) {
                promise.reject("ENOENT", e.message, e)
            }
        }
    }

    @ReactMethod
    fun copyFile(filepath: String, destPath: String, options: ReadableMap?, promise: Promise) {
        val src = sandboxedPath(filepath, promise) ?: return
        val dst = sandboxedPath(destPath, promise) ?: return
        executor.execute {
            try {
                File(dst).parentFile?.mkdirs()
                File(src).copyTo(File(dst), overwrite = true)
                promise.resolve(null)
            } catch (e: Exception) {
                promise.reject("ENOENT", e.message, e)
            }
        }
    }

    @ReactMethod
    fun appendFile(filepath: String, base64Content: String, promise: Promise) {
        val path = sandboxedPath(filepath, promise) ?: return
        executor.execute {
            try {
                val data = Base64.decode(base64Content, Base64.DEFAULT)
                FileOutputStream(path, true).use { it.write(data) }
                promise.resolve(null)
            } catch (e: Exception) {
                promise.reject("ENOENT", e.message, e)
            }
        }
    }

    @ReactMethod
    fun write(filepath: String, base64Content: String, position: Int, promise: Promise) {
        val path = sandboxedPath(filepath, promise) ?: return
        executor.execute {
            try {
                val data = Base64.decode(base64Content, Base64.DEFAULT)
                RandomAccessFile(path, "rw").use { raf ->
                    if (position >= 0) raf.seek(position.toLong()) else raf.seek(raf.length())
                    raf.write(data)
                }
                promise.resolve(null)
            } catch (e: Exception) {
                promise.reject("ENOENT", e.message, e)
            }
        }
    }

    @ReactMethod
    fun read(filepath: String, length: Int, position: Int, promise: Promise) {
        val path = sandboxedPath(filepath, promise) ?: return
        executor.execute {
            try {
                val file = File(path)
                if (!file.exists()) {
                    promise.reject("ENOENT", "No such file '$path'")
                    return@execute
                }
                FileInputStream(path).use { fis ->
                    fis.skip(position.toLong())
                    val buf = if (length > 0) ByteArray(length) else file.readBytes()
                    val bytesRead = if (length > 0) fis.read(buf) else buf.size
                    val result = if (bytesRead > 0) {
                        Base64.encodeToString(buf, 0, bytesRead, Base64.NO_WRAP)
                    } else ""
                    promise.resolve(result)
                }
            } catch (e: Exception) {
                promise.reject("ENOENT", e.message, e)
            }
        }
    }

    @ReactMethod
    fun hash(filepath: String, algorithm: String, promise: Promise) {
        val path = sandboxedPath(filepath, promise) ?: return
        executor.execute {
            try {
                val algoMap = mapOf(
                    "md5" to "MD5", "sha1" to "SHA-1", "sha224" to "SHA-224",
                    "sha256" to "SHA-256", "sha384" to "SHA-384", "sha512" to "SHA-512"
                )
                val javaAlgo = algoMap[algorithm]
                if (javaAlgo == null) {
                    promise.reject("Error", "Invalid hash algorithm '$algorithm'")
                    return@execute
                }
                val md = MessageDigest.getInstance(javaAlgo)
                FileInputStream(path).use { fis ->
                    val buf = ByteArray(8192)
                    var len: Int
                    while (fis.read(buf).also { len = it } != -1) md.update(buf, 0, len)
                }
                val hex = md.digest().joinToString("") { "%02x".format(it) }
                promise.resolve(hex)
            } catch (e: Exception) {
                promise.reject("Error", e.message, e)
            }
        }
    }

    @ReactMethod
    fun getFSInfo(promise: Promise) {
        if (!configured) {
            promise.reject("EPERM", "SandboxedRNFSManager: sandbox not configured.")
            return
        }
        executor.execute {
            try {
                val stat = android.os.StatFs(sandboxRoot)
                val result = Arguments.createMap()
                result.putDouble("totalSpace", stat.totalBytes.toDouble())
                result.putDouble("freeSpace", stat.availableBytes.toDouble())
                promise.resolve(result)
            } catch (e: Exception) {
                promise.reject("Error", e.message, e)
            }
        }
    }

    @ReactMethod
    fun touch(filepath: String, mtime: Double, ctime: Double, promise: Promise) {
        val path = sandboxedPath(filepath, promise) ?: return
        executor.execute {
            try {
                File(path).setLastModified((mtime * 1000).toLong())
                promise.resolve(null)
            } catch (e: Exception) {
                promise.reject("ENOENT", e.message, e)
            }
        }
    }

    @ReactMethod
    fun downloadFile(options: ReadableMap, promise: Promise) {
        promise.reject("EPERM", "downloadFile is not available in sandboxed mode")
    }

    @ReactMethod
    fun stopDownload(jobId: Int) {
        Log.w(TAG, "stopDownload blocked in sandbox")
    }

    @ReactMethod
    fun uploadFiles(options: ReadableMap, promise: Promise) {
        promise.reject("EPERM", "uploadFiles is not available in sandboxed mode")
    }

    @ReactMethod
    fun pathForBundle(bundleName: String, promise: Promise) {
        promise.reject("EPERM", "pathForBundle is not available in sandboxed mode")
    }

    @ReactMethod
    fun pathForGroup(groupId: String, promise: Promise) {
        promise.reject("EPERM", "pathForGroup is not available in sandboxed mode")
    }

    @ReactMethod
    fun addListener(eventName: String) = Unit

    @ReactMethod
    fun removeListeners(count: Double) = Unit
}
