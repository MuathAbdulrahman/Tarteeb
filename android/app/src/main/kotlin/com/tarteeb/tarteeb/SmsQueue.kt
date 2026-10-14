package com.tarteeb.tarteeb

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * Small persistent queue for financial SMS received while the Flutter side
 * may not be running. Entries are removed as soon as Dart acknowledges them
 * (after the parsed transaction is saved). Excluded from platform backups.
 * Only messages that passed [FinancialFilter] are stored.
 */
object SmsQueue {
    private const val PREFS = "tarteeb_sms_queue"
    private const val KEY = "items"
    private const val SETTINGS = "tarteeb_sms_settings"
    private const val KEY_ENABLED = "enabled"
    private const val MAX_ITEMS = 500

    fun isEnabled(ctx: Context): Boolean =
        ctx.getSharedPreferences(SETTINGS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)

    fun setEnabled(ctx: Context, enabled: Boolean) {
        ctx.getSharedPreferences(SETTINGS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    @Synchronized
    private fun load(ctx: Context): JSONArray {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (e: Exception) {
            JSONArray()
        }
    }

    @Synchronized
    private fun save(ctx: Context, arr: JSONArray) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).commit()
    }

    @Synchronized
    fun add(ctx: Context, sender: String, body: String, receivedAt: Long, sentAt: Long) {
        val arr = load(ctx)
        // Drop exact repeats of the same delivery.
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.optString("sender") == sender && o.optString("body") == body && o.optLong("sentAt") == sentAt) return
        }
        val o = JSONObject()
        o.put("id", UUID.randomUUID().toString())
        o.put("sender", sender)
        o.put("body", body)
        o.put("receivedAt", receivedAt)
        o.put("sentAt", sentAt)
        arr.put(o)
        val trimmed = if (arr.length() > MAX_ITEMS) {
            val t = JSONArray()
            for (i in arr.length() - MAX_ITEMS until arr.length()) t.put(arr.get(i))
            t
        } else arr
        save(ctx, trimmed)
    }

    @Synchronized
    fun peek(ctx: Context): List<Map<String, Any>> {
        val arr = load(ctx)
        val out = ArrayList<Map<String, Any>>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            out.add(
                mapOf(
                    "id" to o.optString("id"),
                    "sender" to o.optString("sender"),
                    "body" to o.optString("body"),
                    "receivedAt" to o.optLong("receivedAt"),
                    "sentAt" to o.optLong("sentAt"),
                )
            )
        }
        return out
    }

    @Synchronized
    fun ack(ctx: Context, ids: Collection<String>) {
        val set = ids.toHashSet()
        val arr = load(ctx)
        val keep = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (!set.contains(o.optString("id"))) keep.put(o)
        }
        save(ctx, keep)
    }

    @Synchronized
    fun clear(ctx: Context) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY).commit()
    }
}
