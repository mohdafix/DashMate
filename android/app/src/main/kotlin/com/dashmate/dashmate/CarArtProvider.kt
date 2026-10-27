package com.dashmate.dashmate

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.graphics.Bitmap
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.FileOutputStream
import java.io.FileNotFoundException
import java.util.regex.Pattern

class CarArtProvider : ContentProvider() {

    private val filenamePattern = Pattern.compile("^[A-Za-z0-9_.-]+\\.(jpg|png)$")

    companion object {
        const val AUTHORITY = "com.dashmate.dashmate.carart"
        val CONTENT_URI: Uri = Uri.parse("content://$AUTHORITY")

        fun getArtUri(filename: String): Uri {
            return Uri.parse("content://$AUTHORITY/$filename")
        }

        fun saveArt(context: Context, filename: String, bitmap: Bitmap): Uri? {
            return try {
                val dir = File(context.cacheDir, "car_art")
                if (!dir.exists()) dir.mkdirs()
                val file = File(dir, filename)
                FileOutputStream(file).use { out ->
                    val format = if (filename.endsWith(".png", ignoreCase = true)) {
                        Bitmap.CompressFormat.PNG
                    } else {
                        Bitmap.CompressFormat.JPEG
                    }
                    bitmap.compress(format, 90, out)
                }
                getArtUri(filename)
            } catch (e: Exception) {
                e.printStackTrace()
                null
            }
        }

        fun saveArtBytes(context: Context, filename: String, bytes: ByteArray): Uri? {
            return try {
                val dir = File(context.cacheDir, "car_art")
                if (!dir.exists()) dir.mkdirs()
                val file = File(dir, filename)
                FileOutputStream(file).use { out ->
                    out.write(bytes)
                }
                getArtUri(filename)
            } catch (e: Exception) {
                e.printStackTrace()
                null
            }
        }
    }

    override fun onCreate(): Boolean {
        context?.let { ctx ->
            val dir = File(ctx.cacheDir, "car_art")
            if (!dir.exists()) dir.mkdirs()
        }
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?
    ): Cursor? = null

    override fun getType(uri: Uri): String {
        val segment = uri.lastPathSegment ?: ""
        return if (segment.endsWith(".png", ignoreCase = true)) {
            "image/png"
        } else {
            "image/jpeg"
        }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?
    ): Int = 0

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        if (mode != "r") {
            throw SecurityException("DashMate CarArtProvider only supports read mode")
        }
        val filename = uri.lastPathSegment ?: throw FileNotFoundException("Missing file name")
        if (!filenamePattern.matcher(filename).matches()) {
            throw SecurityException("Invalid file name format: $filename")
        }
        val ctx = context ?: throw FileNotFoundException("No context available")
        val dir = File(ctx.cacheDir, "car_art")
        val file = File(dir, filename)
        val canonicalDir = dir.canonicalFile
        val canonicalFile = file.canonicalFile
        if (!canonicalFile.path.startsWith(canonicalDir.path)) {
            throw SecurityException("Path traversal attempt")
        }
        if (!canonicalFile.exists()) {
            throw FileNotFoundException("File not found: ${file.absolutePath}")
        }
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }
}
