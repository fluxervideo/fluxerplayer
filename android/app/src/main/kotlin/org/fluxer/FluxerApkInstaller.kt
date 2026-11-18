// FluxerPlayer: instalar una actualización (APK) desde la propia app, en el
// móvil y en la tele. Dart descarga el APK en la caché
// (cache/fluxer_update/) y aquí se le pasa al instalador de Android con un
// proveedor propio de solo lectura (sin depender de androidx FileProvider).
// La primera vez, Android pide permitir que FluxerPlayer instale apps.
//
// Enganches: MainActivity.configureFlutterEngine y AndroidManifest.xml
// (permiso REQUEST_INSTALL_PACKAGES y el <provider>), marcados FLUXER.
// Dart: lib/fluxer/update/fluxer_android_update.dart.

package org.fluxer

import android.app.Activity
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException

object FluxerApkInstaller {
    private const val CHANNEL = "fluxer/apk_installer"
    const val DIR = "fluxer_update"
    private const val MIME = "application/vnd.android.package-archive"

    fun register(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "install" -> {
                    val name = call.argument<String>("name")
                    if (name.isNullOrBlank() || name.contains('/')) {
                        result.error("bad_name", "Nombre de archivo no válido", null)
                        return@setMethodCallHandler
                    }
                    val file = File(File(activity.cacheDir, DIR), name)
                    if (!file.exists()) {
                        result.error("missing", "No está el APK descargado", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = Uri.parse("content://${activity.packageName}.fluxerupdate/$name")
                        val intent = Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, MIME)
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        activity.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("no_installer", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

/** Sirve, solo para leer, los APK descargados en cache/fluxer_update/. */
class FluxerApkProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    private fun fileFor(uri: Uri): File {
        val context = context ?: throw FileNotFoundException()
        val dir = File(context.cacheDir, FluxerApkInstaller.DIR)
        val name = uri.lastPathSegment ?: throw FileNotFoundException()
        val file = File(dir, name)
        if (file.canonicalFile.parentFile != dir.canonicalFile || !file.exists()) throw FileNotFoundException()
        return file
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor =
        ParcelFileDescriptor.open(fileFor(uri), ParcelFileDescriptor.MODE_READ_ONLY)

    override fun getType(uri: Uri): String = "application/vnd.android.package-archive"

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val file = fileFor(uri)
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cursor = MatrixCursor(columns)
        cursor.addRow(columns.map<String, Any?> { if (it == OpenableColumns.SIZE) file.length() else file.name }.toTypedArray())
        return cursor
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0
}
