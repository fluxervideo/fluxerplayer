// FluxerPlayer: Instala el APK descargado. Primero con PackageInstaller: desde
// Android 12, al actualizarse a sí misma, puede hacerlo sin preguntar. Si no
// se puede, abre el instalador de Android como siempre.

package org.fluxer

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.util.concurrent.atomic.AtomicBoolean

object FluxerApkInstaller {
    private const val CHANNEL = "fluxer/apk_installer"
    const val DIR = "fluxer_update"
    private const val MIME = "application/vnd.android.package-archive"
    const val EXTRA_NAME = "org.fluxer.apk_name"
    private const val PREFS = "fluxer_update"
    private const val KEY_NOTICE = "notice_after_update"
    private const val SESSION_TIMEOUT_MS = 30_000L

    /** Marca que la próxima sustitución de la app viene de una actualización suya. */
    fun setUpdateNotice(context: Context, pending: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_NOTICE, pending).apply()
    }

    fun takeUpdateNotice(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pending = prefs.getBoolean(KEY_NOTICE, false)
        if (pending) prefs.edit().remove(KEY_NOTICE).apply()
        return pending
    }

    /** El instalador de Android de siempre, con el APK [name] de cache/fluxer_update/. */
    fun viewIntent(context: Context, name: String): Intent {
        val uri = Uri.parse("content://${context.packageName}.fluxerupdate/$name")
        return Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, MIME)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    private fun installWithSession(context: Context, file: File, onSession: (PackageInstaller.Session) -> Unit, claim: () -> Boolean) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName(context.packageName)
        params.setSize(file.length())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }
        val sessionId = installer.createSession(params)
        val session = installer.openSession(sessionId)
        onSession(session)
        try {
            file.inputStream().use { input ->
                session.openWrite("base.apk", 0, file.length()).use { out ->
                    input.copyTo(out)
                    session.fsync(out)
                }
            }
            val intent = Intent(context, FluxerInstallResultReceiver::class.java)
                .setPackage(context.packageName)
                .putExtra(EXTRA_NAME, file.name)
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
            val pending = PendingIntent.getBroadcast(context, sessionId, intent, flags)
            if (!claim()) throw IllegalStateException("timeout")
            setUpdateNotice(context, true)
            session.commit(pending.intentSender)
            session.close()
        } catch (e: Exception) {
            setUpdateNotice(context, false)
            try { session.abandon() } catch (_: Exception) {}
            throw e
        }
    }

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
                    // Copiar el APK a la sesión tarda: fuera del hilo principal.
                    // Si tarda demasiado, el instalador de Android de siempre.
                    val done = AtomicBoolean(false)
                    var session: PackageInstaller.Session? = null
                    fun openInstaller() {
                        try {
                            activity.startActivity(viewIntent(activity, name))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("no_installer", e.message, null)
                        }
                    }
                    val main = Handler(Looper.getMainLooper())
                    main.postDelayed({
                        if (!done.compareAndSet(false, true)) return@postDelayed
                        setUpdateNotice(activity, false)
                        try { session?.abandon() } catch (_: Exception) {}
                        openInstaller()
                    }, SESSION_TIMEOUT_MS)
                    Thread {
                        var claimed = false
                        val sessionError = try {
                            installWithSession(activity.applicationContext, file, { session = it }, { done.compareAndSet(false, true).also { claimed = it } })
                            null
                        } catch (e: Exception) {
                            e
                        }
                        main.post {
                            if (sessionError == null) {
                                result.success(true)
                            } else if (claimed || done.compareAndSet(false, true)) {
                                openInstaller()
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }
}

/** Resultado de la instalación con PackageInstaller. */
class FluxerInstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                // Android pide confirmarlo: su ventana de «¿Actualizar?».
                val confirm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                try {
                    if (confirm != null) {
                        context.startActivity(confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    } else {
                        fallback(context, intent)
                    }
                } catch (e: Exception) {
                    fallback(context, intent)
                }
            }
            PackageInstaller.STATUS_SUCCESS -> Unit
            PackageInstaller.STATUS_FAILURE_ABORTED -> FluxerApkInstaller.setUpdateNotice(context, false)
            else -> {
                FluxerApkInstaller.setUpdateNotice(context, false)
                fallback(context, intent)
            }
        }
    }

    private fun fallback(context: Context, intent: Intent) {
        val name = intent.getStringExtra(FluxerApkInstaller.EXTRA_NAME) ?: return
        try {
            context.startActivity(FluxerApkInstaller.viewIntent(context, name))
        } catch (e: Exception) {
        }
    }
}

/**
 * Tras actualizarse desde la app, Android la cierra y no la vuelve a abrir:
 * aviso discreto (sin sonido) para abrirla. Solo si la actualización la
 * empezó FluxerPlayer.
 */
class FluxerUpdatedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        if (!FluxerApkInstaller.takeUpdateNotice(context)) return
        try {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !manager.areNotificationsEnabled()) return
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val open = PendingIntent.getActivity(context, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            val es = java.util.Locale.getDefault().language == "es"
            val title = if (es) "FluxerPlayer actualizado" else "FluxerPlayer updated"
            val text = if (es) "Toca para abrir" else "Tap to open"
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL,
                    if (es) "Actualizaciones" else "Updates",
                    NotificationManager.IMPORTANCE_LOW,
                )
                channel.setSound(null, null)
                manager.createNotificationChannel(channel)
                Notification.Builder(context, CHANNEL)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context).setPriority(Notification.PRIORITY_LOW)
            }
            val notification = builder
                .setSmallIcon(context.resources.getIdentifier("ic_notification", "drawable", context.packageName))
                .setContentTitle(title)
                .setContentText(text)
                .setContentIntent(open)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .build()
            manager.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
        }
    }

    private companion object {
        const val CHANNEL = "fluxer_updates"
        const val NOTIFICATION_ID = 4711
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
