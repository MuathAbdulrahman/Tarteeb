package com.tarteeb.tarteeb

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object Notifications {
    const val CHANNEL_REMINDERS = "reminders"
    const val CHANNEL_TRANSACTIONS = "transactions"

    fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val ar = ctx.resources.configuration.locales[0].language == "ar"
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_REMINDERS,
                if (ar) "التذكيرات" else "Reminders",
                NotificationManager.IMPORTANCE_HIGH
            )
        )
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_TRANSACTIONS,
                if (ar) "العمليات المالية" else "Transactions",
                NotificationManager.IMPORTANCE_DEFAULT
            )
        )
    }

    fun show(ctx: Context, id: Int, title: String, body: String, channel: String) {
        ensureChannels(ctx)
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val launch = Intent(ctx, MainActivity::class.java).addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        )
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        val pi = PendingIntent.getActivity(ctx, 0, launch, flags)
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(ctx, channel)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(ctx)
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_tarteeb)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pi)
            .setAutoCancel(true)
        try {
            nm.notify(id, builder.build())
        } catch (e: SecurityException) {
            // Notification permission not granted; nothing to do.
        }
    }
}
