package com.tarteeb.tarteeb

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Local reminders scheduled with AlarmManager. Dart sends the complete list
 * of reminders on every change ([sync]); this class cancels what is no longer
 * wanted and (re)schedules the rest. The list is persisted so reminders can be
 * restored after a reboot without opening the app.
 *
 * Exact timing needs the "Alarms & reminders" special access on Android 12+;
 * without it reminders use inexact, Doze-friendly alarms that may be delayed.
 */
object Reminders {
    private const val PREFS = "tarteeb_reminders"
    private const val KEY = "items"

    private fun load(ctx: Context): JSONArray {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (e: Exception) {
            JSONArray()
        }
    }

    private fun save(ctx: Context, arr: JSONArray) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
    }

    fun find(ctx: Context, id: Int): JSONObject? {
        val arr = load(ctx)
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.optInt("id") == id) return o
        }
        return null
    }

    private fun remove(ctx: Context, id: Int) {
        val arr = load(ctx)
        val keep = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.optInt("id") != id) keep.put(o)
        }
        save(ctx, keep)
    }

    private fun pending(ctx: Context, id: Int, create: Boolean): PendingIntent? {
        val intent = Intent(ctx, ReminderReceiver::class.java).putExtra("id", id)
        var flags = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0
        flags = flags or if (create) PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_NO_CREATE
        return PendingIntent.getBroadcast(ctx, id, intent, flags)
    }

    fun canExact(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < 31) return true
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    /** Replaces all reminders with [items]. */
    fun sync(ctx: Context, items: List<Map<String, Any?>>) {
        val old = load(ctx)
        val newIds = items.mapNotNull { (it["id"] as? Number)?.toInt() }.toHashSet()
        for (i in 0 until old.length()) {
            val id = old.getJSONObject(i).optInt("id")
            if (!newIds.contains(id)) cancel(ctx, id)
        }
        val arr = JSONArray()
        for (m in items) {
            val o = JSONObject()
            o.put("id", (m["id"] as? Number)?.toInt() ?: continue)
            o.put("title", m["title"] as? String ?: "")
            o.put("body", m["body"] as? String ?: "")
            o.put("kind", m["kind"] as? String ?: "once")
            o.put("at", (m["at"] as? Number)?.toLong() ?: 0L)
            o.put("minutes", (m["minutes"] as? Number)?.toInt() ?: 0)
            o.put("mask", (m["mask"] as? Number)?.toInt() ?: 0)
            o.put("skipUntil", (m["skipUntil"] as? Number)?.toLong() ?: 0L)
            arr.put(o)
        }
        save(ctx, arr)
        for (i in 0 until arr.length()) schedule(ctx, arr.getJSONObject(i))
    }

    /** Re-arms every stored reminder (after boot, update or time change). */
    fun rescheduleAll(ctx: Context) {
        val arr = load(ctx)
        for (i in 0 until arr.length()) schedule(ctx, arr.getJSONObject(i))
    }

    private fun cancel(ctx: Context, id: Int) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        pending(ctx, id, false)?.let {
            am.cancel(it)
            it.cancel()
        }
    }

    fun nextTrigger(o: JSONObject, now: Long): Long? {
        return when (o.optString("kind")) {
            "once" -> {
                val at = o.optLong("at")
                if (at > now) at else null
            }
            "weekly" -> {
                val mask = o.optInt("mask")
                if (mask == 0) return null
                val minutes = o.optInt("minutes")
                val from = maxOf(now + 1000L, o.optLong("skipUntil"))
                val cal = Calendar.getInstance()
                cal.timeInMillis = from
                cal.set(Calendar.HOUR_OF_DAY, minutes / 60)
                cal.set(Calendar.MINUTE, minutes % 60)
                cal.set(Calendar.SECOND, 0)
                cal.set(Calendar.MILLISECOND, 0)
                for (i in 0..8) {
                    val dowIndex = cal.get(Calendar.DAY_OF_WEEK) - 1 // 0 = Sunday
                    if ((mask shr dowIndex) and 1 == 1 && cal.timeInMillis >= from) return cal.timeInMillis
                    cal.add(Calendar.DAY_OF_MONTH, 1)
                    cal.set(Calendar.HOUR_OF_DAY, minutes / 60)
                    cal.set(Calendar.MINUTE, minutes % 60)
                }
                null
            }
            else -> null
        }
    }

    fun schedule(ctx: Context, o: JSONObject) {
        val id = o.optInt("id")
        val t = nextTrigger(o, System.currentTimeMillis())
        if (t == null) {
            cancel(ctx, id)
            if (o.optString("kind") == "once") remove(ctx, id)
            return
        }
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pending(ctx, id, true) ?: return
        if (Build.VERSION.SDK_INT < 23) {
            am.setExact(AlarmManager.RTC_WAKEUP, t, pi)
            return
        }
        try {
            if (canExact(ctx)) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
            }
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
        }
    }

    fun onFired(ctx: Context, id: Int) {
        val o = find(ctx, id) ?: return
        Notifications.show(ctx, id, o.optString("title"), o.optString("body"), Notifications.CHANNEL_REMINDERS)
        if (o.optString("kind") == "weekly") {
            o.put("skipUntil", System.currentTimeMillis() + 60_000L)
            val arr = load(ctx)
            val keep = JSONArray()
            for (i in 0 until arr.length()) {
                val x = arr.getJSONObject(i)
                keep.put(if (x.optInt("id") == id) o else x)
            }
            save(ctx, keep)
            schedule(ctx, o)
        } else {
            remove(ctx, id)
        }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", -1)
        if (id >= 0) Reminders.onFired(context, id)
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> Reminders.rescheduleAll(context)
        }
    }
}
