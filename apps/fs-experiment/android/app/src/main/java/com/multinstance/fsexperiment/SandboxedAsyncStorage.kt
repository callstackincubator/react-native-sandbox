package com.multinstance.fsexperiment

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Callback
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.WritableMap
import com.facebook.react.module.annotations.ReactModule
import io.callstack.rnsandbox.SandboxAwareModule
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Sandboxed AsyncStorage — per-origin SQLite storage that mirrors the original
 * RNCAsyncStorage API but scopes data to the sandbox origin.
 *
 * Uses callbacks (not promises) to match the original AsyncStorageModule interface.
 */
@ReactModule(name = SandboxedAsyncStorage.MODULE_NAME)
class SandboxedAsyncStorage(
    private val reactContext: ReactApplicationContext,
) : ReactContextBaseJavaModule(reactContext), SandboxAwareModule {

    companion object {
        const val MODULE_NAME = "SandboxedAsyncStorage"
        private const val TAG = "SandboxedAsyncStorage"
        private const val TABLE = "kv"
        private const val COL_KEY = "k"
        private const val COL_VALUE = "v"
        private const val DB_VERSION = 1
        private const val MAX_SQL_KEYS = 999
    }

    private val executor = Executors.newSingleThreadExecutor()
    private var dbHelper: SandboxDBHelper? = null
    @Volatile private var configured = false

    override fun getName(): String = MODULE_NAME

    override fun configureSandbox(origin: String, requestedName: String, resolvedName: String) {
        Log.d(TAG, "Configuring for origin '$origin'")
        val dbDir = java.io.File(reactContext.filesDir, "Sandboxes/$origin/AsyncStorage")
        dbDir.mkdirs()
        val dbName = "sandboxed_async_storage.db"
        dbHelper = SandboxDBHelper(reactContext, java.io.File(dbDir, dbName).absolutePath)
        configured = true
    }

    override fun invalidate() {
        executor.shutdown()
        try {
            executor.awaitTermination(2, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
            executor.shutdownNow()
        }
        dbHelper?.close()
        dbHelper = null
        configured = false
        super.invalidate()
    }

    private fun errorMap(message: String): WritableMap {
        val map = Arguments.createMap()
        map.putString("message", message)
        return map
    }

    private fun db(): SQLiteDatabase? = dbHelper?.writableDatabase

    private fun readDb(): SQLiteDatabase? = dbHelper?.readableDatabase

    @ReactMethod
    fun multiGet(keys: ReadableArray, callback: Callback) {
        if (!configured) {
            callback.invoke(errorMap("Sandbox not configured"), null)
            return
        }
        executor.execute {
            try {
                val db = readDb() ?: run {
                    callback.invoke(errorMap("Database not available"), null)
                    return@execute
                }
                val data = Arguments.createArray()
                val keysRemaining = mutableSetOf<String>()

                for (start in 0 until keys.size() step MAX_SQL_KEYS) {
                    val count = minOf(keys.size() - start, MAX_SQL_KEYS)
                    keysRemaining.clear()
                    val placeholders = (0 until count).joinToString(",") { "?" }
                    val args = Array(count) { keys.getString(start + it) ?: "" }
                    for (arg in args) keysRemaining.add(arg)

                    db.rawQuery("SELECT $COL_KEY, $COL_VALUE FROM $TABLE WHERE $COL_KEY IN ($placeholders)", args).use { cursor ->
                        while (cursor.moveToNext()) {
                            val row = Arguments.createArray()
                            row.pushString(cursor.getString(0))
                            row.pushString(cursor.getString(1))
                            data.pushArray(row)
                            keysRemaining.remove(cursor.getString(0))
                        }
                    }

                    for (key in keysRemaining) {
                        val row = Arguments.createArray()
                        row.pushString(key)
                        row.pushNull()
                        data.pushArray(row)
                    }
                }
                callback.invoke(null, data)
            } catch (e: Exception) {
                Log.e(TAG, "multiGet failed", e)
                callback.invoke(errorMap(e.message ?: "Unknown error"), null)
            }
        }
    }

    @ReactMethod
    fun multiSet(keyValueArray: ReadableArray, callback: Callback) {
        if (!configured) {
            callback.invoke(errorMap("Sandbox not configured"))
            return
        }
        executor.execute {
            try {
                val db = db() ?: run {
                    callback.invoke(errorMap("Database not available"))
                    return@execute
                }
                db.beginTransaction()
                try {
                    for (i in 0 until keyValueArray.size()) {
                        val pair = keyValueArray.getArray(i) ?: continue
                        if (pair.size() != 2) continue
                        val key = pair.getString(0) ?: continue
                        val value = pair.getString(1) ?: continue

                        val cv = ContentValues()
                        cv.put(COL_KEY, key)
                        cv.put(COL_VALUE, value)
                        db.insertWithOnConflict(TABLE, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
                    }
                    db.setTransactionSuccessful()
                } finally {
                    db.endTransaction()
                }
                callback.invoke()
            } catch (e: Exception) {
                Log.e(TAG, "multiSet failed", e)
                callback.invoke(errorMap(e.message ?: "Unknown error"))
            }
        }
    }

    @ReactMethod
    fun multiRemove(keys: ReadableArray, callback: Callback) {
        if (!configured) {
            callback.invoke(errorMap("Sandbox not configured"))
            return
        }
        executor.execute {
            try {
                val db = db() ?: run {
                    callback.invoke(errorMap("Database not available"))
                    return@execute
                }
                db.beginTransaction()
                try {
                    for (start in 0 until keys.size() step MAX_SQL_KEYS) {
                        val count = minOf(keys.size() - start, MAX_SQL_KEYS)
                        val placeholders = (0 until count).joinToString(",") { "?" }
                        val args = Array(count) { keys.getString(start + it) ?: "" }
                        db.delete(TABLE, "$COL_KEY IN ($placeholders)", args)
                    }
                    db.setTransactionSuccessful()
                } finally {
                    db.endTransaction()
                }
                callback.invoke()
            } catch (e: Exception) {
                Log.e(TAG, "multiRemove failed", e)
                callback.invoke(errorMap(e.message ?: "Unknown error"))
            }
        }
    }

    @ReactMethod
    fun multiMerge(keyValueArray: ReadableArray, callback: Callback) {
        if (!configured) {
            callback.invoke(errorMap("Sandbox not configured"))
            return
        }
        executor.execute {
            try {
                val db = db() ?: run {
                    callback.invoke(errorMap("Database not available"))
                    return@execute
                }
                db.beginTransaction()
                try {
                    for (i in 0 until keyValueArray.size()) {
                        val pair = keyValueArray.getArray(i) ?: continue
                        if (pair.size() != 2) continue
                        val key = pair.getString(0) ?: continue
                        val newValue = pair.getString(1) ?: continue

                        val existing = getValueForKey(db, key)
                        val merged = if (existing != null) {
                            mergeJsonStrings(existing, newValue) ?: newValue
                        } else {
                            newValue
                        }
                        val cv = ContentValues()
                        cv.put(COL_KEY, key)
                        cv.put(COL_VALUE, merged)
                        db.insertWithOnConflict(TABLE, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
                    }
                    db.setTransactionSuccessful()
                } finally {
                    db.endTransaction()
                }
                callback.invoke()
            } catch (e: Exception) {
                Log.e(TAG, "multiMerge failed", e)
                callback.invoke(errorMap(e.message ?: "Unknown error"))
            }
        }
    }

    @ReactMethod
    fun getAllKeys(callback: Callback) {
        if (!configured) {
            callback.invoke(errorMap("Sandbox not configured"), null)
            return
        }
        executor.execute {
            try {
                val db = readDb() ?: run {
                    callback.invoke(errorMap("Database not available"), null)
                    return@execute
                }
                val keys = Arguments.createArray()
                db.rawQuery("SELECT $COL_KEY FROM $TABLE", null).use { cursor ->
                    while (cursor.moveToNext()) {
                        keys.pushString(cursor.getString(0))
                    }
                }
                callback.invoke(null, keys)
            } catch (e: Exception) {
                Log.e(TAG, "getAllKeys failed", e)
                callback.invoke(errorMap(e.message ?: "Unknown error"), null)
            }
        }
    }

    @ReactMethod
    fun clear(callback: Callback) {
        if (!configured) {
            callback.invoke(errorMap("Sandbox not configured"))
            return
        }
        executor.execute {
            try {
                val db = db() ?: run {
                    callback.invoke(errorMap("Database not available"))
                    return@execute
                }
                db.delete(TABLE, null, null)
                callback.invoke()
            } catch (e: Exception) {
                Log.e(TAG, "clear failed", e)
                callback.invoke(errorMap(e.message ?: "Unknown error"))
            }
        }
    }

    private fun getValueForKey(db: SQLiteDatabase, key: String): String? {
        db.rawQuery("SELECT $COL_VALUE FROM $TABLE WHERE $COL_KEY = ?", arrayOf(key)).use { cursor ->
            return if (cursor.moveToFirst()) cursor.getString(0) else null
        }
    }

    /**
     * Deep recursive merge matching the original RNCAsyncStorage behavior:
     * when both sides have a JSONObject at a given key, merge recursively;
     * otherwise the new value overwrites the old one.
     */
    private fun mergeJsonStrings(existing: String, incoming: String): String? {
        return try {
            val base = JSONObject(existing)
            val overlay = JSONObject(incoming)
            deepMerge(base, overlay)
            base.toString()
        } catch (e: Exception) {
            null
        }
    }

    private fun deepMerge(base: JSONObject, overlay: JSONObject) {
        for (key in overlay.keys()) {
            val newValue = overlay.get(key)
            val oldValue = base.opt(key)
            if (oldValue is JSONObject && newValue is JSONObject) {
                deepMerge(oldValue, newValue)
            } else {
                base.put(key, newValue)
            }
        }
    }

    private class SandboxDBHelper(context: Context, dbPath: String) :
        SQLiteOpenHelper(context, dbPath, null, DB_VERSION) {

        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE IF NOT EXISTS $TABLE ($COL_KEY TEXT PRIMARY KEY, $COL_VALUE TEXT NOT NULL)")
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            db.execSQL("DROP TABLE IF EXISTS $TABLE")
            onCreate(db)
        }
    }
}
