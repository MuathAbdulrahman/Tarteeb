package com.tarteeb.tarteeb

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "tarteeb/native"
        private const val REQ_SMS = 7101
        private const val REQ_NOTIF = 7102
        private const val REQ_CREATE_DOC = 7103
        private const val REQ_OPEN_DOC = 7104
        private const val PERM_PREFS = "tarteeb_perm_asked"
        private const val MAX_DOC_BYTES = 30 * 1024 * 1024

        private var channelRef: WeakReference<MethodChannel>? = null

        /** Called by [SmsReceiver] on the main thread when a message was queued. */
        fun notifySmsQueued() {
            Handler(Looper.getMainLooper()).post {
                try {
                    channelRef?.get()?.invokeMethod("smsQueued", null)
                } catch (e: Exception) {
                    // Engine not attached; the queue is drained on next start.
                }
            }
        }
    }

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingSms: MethodChannel.Result? = null
    private var pendingNotif: MethodChannel.Result? = null
    private var pendingCreate: MethodChannel.Result? = null
    private var pendingCreateBytes: ByteArray? = null
    private var pendingOpen: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channelRef = WeakReference(ch)
        ch.setMethodCallHandler { call, result -> handle(call, result) }
        Notifications.ensureChannels(this)
    }

    override fun onDestroy() {
        io.shutdown()
        super.onDestroy()
    }

    // ------------------------------------------------------------ permissions

    private fun hasTelephony(): Boolean =
        packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)

    private fun granted(p: String): Boolean =
        Build.VERSION.SDK_INT < 23 || checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun asked(p: String): Boolean =
        getSharedPreferences(PERM_PREFS, Context.MODE_PRIVATE).getBoolean(p, false)

    private fun markAsked(ps: Array<String>) {
        val e = getSharedPreferences(PERM_PREFS, Context.MODE_PRIVATE).edit()
        ps.forEach { e.putBoolean(it, true) }
        e.apply()
    }

    private fun permState(p: String): String {
        if (granted(p)) return "granted"
        if (Build.VERSION.SDK_INT >= 23 && asked(p) && !shouldShowRequestPermissionRationale(p)) {
            return "permanentlyDenied"
        }
        return "denied"
    }

    private fun smsStatus(): Map<String, String> {
        if (!hasTelephony()) return mapOf("read" to "unavailable", "receive" to "unavailable")
        return mapOf(
            "read" to permState(Manifest.permission.READ_SMS),
            "receive" to permState(Manifest.permission.RECEIVE_SMS),
        )
    }

    private fun notifState(): String {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 33) {
            return permState(Manifest.permission.POST_NOTIFICATIONS)
        }
        return if (nm.areNotificationsEnabled()) "granted" else "permanentlyDenied"
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            REQ_SMS -> {
                pendingSms?.success(smsStatus())
                pendingSms = null
            }
            REQ_NOTIF -> {
                pendingNotif?.success(notifState())
                pendingNotif = null
            }
        }
    }

    // ------------------------------------------------------------ documents

    @Deprecated("Uses the platform activity result API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQ_CREATE_DOC -> {
                val r = pendingCreate
                val bytes = pendingCreateBytes
                pendingCreate = null
                pendingCreateBytes = null
                val uri = data?.data
                if (r == null) return
                if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
                    r.success(false)
                    return
                }
                io.execute {
                    val ok = try {
                        contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes) } != null
                    } catch (e: Exception) {
                        false
                    }
                    main.post { r.success(ok) }
                }
            }
            REQ_OPEN_DOC -> {
                val r = pendingOpen ?: return
                pendingOpen = null
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) {
                    r.success(null)
                    return
                }
                io.execute {
                    val bytes = try {
                        contentResolver.openInputStream(uri)?.use { input ->
                            val buf = java.io.ByteArrayOutputStream()
                            val chunk = ByteArray(64 * 1024)
                            var total = 0
                            while (true) {
                                val n = input.read(chunk)
                                if (n < 0) break
                                total += n
                                if (total > MAX_DOC_BYTES) throw IllegalStateException("too large")
                                buf.write(chunk, 0, n)
                            }
                            buf.toByteArray()
                        }
                    } catch (e: Exception) {
                        null
                    }
                    main.post { r.success(bytes) }
                }
            }
        }
    }

    // ------------------------------------------------------------ inbox

    private fun queryInbox(from: Long, to: Long): Map<String, Any> {
        val items = ArrayList<Map<String, Any>>()
        var scanned = 0
        if (!granted(Manifest.permission.READ_SMS)) return mapOf("scanned" to 0, "items" to items)
        val projection = arrayOf(
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.DATE_SENT,
        )
        contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            "${Telephony.Sms.DATE} >= ? AND ${Telephony.Sms.DATE} < ?",
            arrayOf(from.toString(), to.toString()),
            "${Telephony.Sms.DATE} ASC"
        )?.use { c ->
            val iAddr = c.getColumnIndex(Telephony.Sms.ADDRESS)
            val iBody = c.getColumnIndex(Telephony.Sms.BODY)
            val iDate = c.getColumnIndex(Telephony.Sms.DATE)
            val iSent = c.getColumnIndex(Telephony.Sms.DATE_SENT)
            while (c.moveToNext()) {
                scanned++
                val body = if (iBody >= 0) c.getString(iBody) else null
                if (!FinancialFilter.isCandidate(body)) continue
                items.add(
                    mapOf(
                        "sender" to (if (iAddr >= 0) c.getString(iAddr) ?: "" else ""),
                        "body" to (body ?: ""),
                        "date" to (if (iDate >= 0) c.getLong(iDate) else 0L),
                        "dateSent" to (if (iSent >= 0) c.getLong(iSent) else 0L),
                    )
                )
            }
        }
        return mapOf("scanned" to scanned, "items" to items)
    }

    // ------------------------------------------------------------ dispatch

    private fun openSettingsIntent(action: String, withPackage: Boolean): Boolean {
        return try {
            val i = Intent(action)
            if (withPackage) i.data = Uri.fromParts("package", packageName, null)
            startActivity(i)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "smsPermissionStatus" -> result.success(smsStatus())

            "requestSmsPermissions" -> {
                if (!hasTelephony() || Build.VERSION.SDK_INT < 23) {
                    result.success(smsStatus())
                    return
                }
                val which = call.argument<List<String>>("which") ?: listOf("read")
                val perms = which.mapNotNull {
                    when (it) {
                        "read" -> Manifest.permission.READ_SMS
                        "receive" -> Manifest.permission.RECEIVE_SMS
                        else -> null
                    }
                }.filter { !granted(it) }.toTypedArray()
                if (perms.isEmpty()) {
                    result.success(smsStatus())
                    return
                }
                if (pendingSms != null) {
                    result.error("busy", "Permission request in progress", null)
                    return
                }
                pendingSms = result
                markAsked(perms)
                requestPermissions(perms, REQ_SMS)
            }

            "querySmsInbox" -> {
                val from = call.argument<Number>("from")?.toLong() ?: 0L
                val to = call.argument<Number>("to")?.toLong() ?: System.currentTimeMillis()
                io.execute {
                    val r = try {
                        queryInbox(from, to)
                    } catch (e: Exception) {
                        mapOf("scanned" to 0, "items" to emptyList<Any>())
                    }
                    main.post { result.success(r) }
                }
            }

            "setSmsProcessingEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                SmsQueue.setEnabled(this, enabled)
                if (!enabled) SmsQueue.clear(this)
                result.success(null)
            }

            "peekSmsQueue" -> result.success(SmsQueue.peek(this))

            "ackSmsQueue" -> {
                SmsQueue.ack(this, call.argument<List<String>>("ids") ?: emptyList())
                result.success(null)
            }

            "clearSmsQueue" -> {
                SmsQueue.clear(this)
                result.success(null)
            }

            "notificationPermission" -> result.success(notifState())

            "requestNotificationPermission" -> {
                if (Build.VERSION.SDK_INT < 33 || granted(Manifest.permission.POST_NOTIFICATIONS)) {
                    result.success(notifState())
                    return
                }
                if (pendingNotif != null) {
                    result.error("busy", "Permission request in progress", null)
                    return
                }
                pendingNotif = result
                markAsked(arrayOf(Manifest.permission.POST_NOTIFICATIONS))
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIF)
            }

            "canScheduleExact" -> result.success(Reminders.canExact(this))

            "openExactAlarmSettings" -> {
                if (Build.VERSION.SDK_INT >= 31) {
                    if (!openSettingsIntent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, true)) {
                        openSettingsIntent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, true)
                    }
                }
                result.success(null)
            }

            "openAppSettings" -> {
                openSettingsIntent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, true)
                result.success(null)
            }

            "syncReminders" -> {
                @Suppress("UNCHECKED_CAST")
                val items = call.argument<List<Map<String, Any?>>>("items") ?: emptyList()
                Reminders.sync(this, items)
                result.success(null)
            }

            "showNotification" -> {
                val title = call.argument<String>("title") ?: ""
                val body = call.argument<String>("body") ?: ""
                val channel = call.argument<String>("channel") ?: Notifications.CHANNEL_TRANSACTIONS
                val id = (System.currentTimeMillis() % 1_000_000L).toInt() + 1_000_000
                Notifications.show(this, id, title, body, channel)
                result.success(null)
            }

            "saveDocument" -> {
                val name = call.argument<String>("name") ?: "tarteeb-backup.json"
                val mime = call.argument<String>("mime") ?: "application/json"
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null || pendingCreate != null) {
                    result.success(false)
                    return
                }
                pendingCreate = result
                pendingCreateBytes = bytes
                val i = Intent(Intent.ACTION_CREATE_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType(mime)
                    .putExtra(Intent.EXTRA_TITLE, name)
                try {
                    @Suppress("DEPRECATION")
                    startActivityForResult(i, REQ_CREATE_DOC)
                } catch (e: Exception) {
                    pendingCreate = null
                    pendingCreateBytes = null
                    result.success(false)
                }
            }

            "openDocument" -> {
                if (pendingOpen != null) {
                    result.success(null)
                    return
                }
                pendingOpen = result
                val i = Intent(Intent.ACTION_OPEN_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("*/*")
                    .putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                try {
                    @Suppress("DEPRECATION")
                    startActivityForResult(i, REQ_OPEN_DOC)
                } catch (e: Exception) {
                    pendingOpen = null
                    result.success(null)
                }
            }

            "encrypt" -> {
                val data = call.argument<ByteArray>("data")
                val pw = call.argument<String>("password")
                if (data == null || pw.isNullOrEmpty()) {
                    result.success(null)
                    return
                }
                io.execute {
                    val r = try {
                        CryptoUtil.encrypt(data, pw)
                    } catch (e: Exception) {
                        null
                    }
                    main.post { result.success(r) }
                }
            }

            "decrypt" -> {
                val env = call.argument<Map<*, *>>("envelope")
                val pw = call.argument<String>("password")
                if (env == null || pw.isNullOrEmpty()) {
                    result.success(null)
                    return
                }
                io.execute {
                    val r = CryptoUtil.decrypt(env, pw)
                    main.post { result.success(r) }
                }
            }

            else -> result.notImplemented()
        }
    }
}
