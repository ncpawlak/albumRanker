package com.ncpawlak.albumrank

import android.content.ContentUris
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "albumrank/backup").setMethodCallHandler { call, result ->
            if (call.method != "saveToDownloads") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val path = saveBackup(
                    name = call.argument<String>("fileName")!!,
                    bytes = call.argument<String>("contents")!!.toByteArray(Charsets.UTF_8),
                    prefix = call.argument<String>("prefix") ?: "",
                    keep = call.argument<Int>("keep") ?: 5,
                )
                result.success(path)
            } catch (e: Exception) {
                result.error("BACKUP_FAILED", e.message, null)
            }
        }
    }

    /** Writes to Downloads/AlbumRank and deletes all but the newest [keep] backups. */
    private fun saveBackup(name: String, bytes: ByteArray, prefix: String, keep: Int): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            // Pre-Android 10 needs a storage permission for public Downloads; use app storage instead.
            val dir = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "AlbumRank").apply { mkdirs() }
            File(dir, name).writeBytes(bytes)
            dir.listFiles { f -> f.name.startsWith(prefix) }
                ?.sortedByDescending { it.name }
                ?.drop(keep)
                ?.forEach { it.delete() }
            return File(dir, name).absolutePath
        }

        val resolver = contentResolver
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val relativePath = Environment.DIRECTORY_DOWNLOADS + "/AlbumRank/"
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(collection, values) ?: throw IllegalStateException("Could not create $name")
        resolver.openOutputStream(uri)!!.use { it.write(bytes) }
        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, values, null, null)

        // Names are timestamped, so sorting by name newest-first finds the old ones.
        resolver.query(
            collection,
            arrayOf(MediaStore.MediaColumns._ID),
            "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND ${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?",
            arrayOf(relativePath, "$prefix%"),
            "${MediaStore.MediaColumns.DISPLAY_NAME} DESC",
        )?.use { cursor ->
            var index = 0
            while (cursor.moveToNext()) {
                if (index++ >= keep) {
                    resolver.delete(ContentUris.withAppendedId(collection, cursor.getLong(0)), null, null)
                }
            }
        }
        return "Downloads/AlbumRank/$name"
    }
}
