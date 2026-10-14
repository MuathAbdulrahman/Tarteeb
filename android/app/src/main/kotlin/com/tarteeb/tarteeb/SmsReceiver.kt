package com.tarteeb.tarteeb

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Receives SMS_RECEIVED (a broadcast still allowed for manifest receivers).
 * Multipart messages arrive as several PDUs in one intent; parts from the same
 * sender are joined in order. Only financial candidates are queued, and only
 * while the user has enabled new-message processing. Nothing is logged.
 *
 * Limits (documented in docs/SMS_SUPPORT.md): Android does not deliver this
 * broadcast to an app that was force-stopped until the user opens it again;
 * the app then recovers missed messages by re-reading the inbox.
 */
private class SmsAcc(val sender: String, val sb: StringBuilder, var sentAt: Long)

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!SmsQueue.isEnabled(context)) return
        val parts = try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent)
        } catch (e: Exception) {
            null
        } ?: return
        if (parts.isEmpty()) return

        val bySender = LinkedHashMap<String, SmsAcc>()
        for (p in parts) {
            if (p == null) continue
            val sender = p.displayOriginatingAddress ?: p.originatingAddress ?: ""
            val acc = bySender.getOrPut(sender) { SmsAcc(sender, StringBuilder(), p.timestampMillis) }
            acc.sb.append(p.displayMessageBody ?: p.messageBody ?: "")
            if (acc.sentAt <= 0L) acc.sentAt = p.timestampMillis
        }
        val now = System.currentTimeMillis()
        var queued = false
        for (acc in bySender.values) {
            val body = acc.sb.toString()
            if (FinancialFilter.isCandidate(body)) {
                SmsQueue.add(context, acc.sender, body, now, acc.sentAt)
                queued = true
            }
        }
        if (queued) MainActivity.notifySmsQueued()
    }
}
