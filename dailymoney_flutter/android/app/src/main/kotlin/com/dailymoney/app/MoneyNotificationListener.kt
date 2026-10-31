package com.dailymoney.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject
import java.time.Instant
import java.util.UUID

/**
 * Reads payment-style notifications and queues them for review inside the app.
 *
 * Nothing is written to the ledger here. Each detection is encrypted with an
 * Android Keystore key by [SecureCaptureQueue], and the Dart side moves it into
 * the encrypted ledger store the next time the app is opened.
 *
 * The listener only runs when the user has granted notification access and
 * enabled automatic tracking in Settings.
 */
class MoneyNotificationListener : NotificationListenerService() {

    companion object {
        private const val PREFS = "FlutterSharedPreferences"
        private const val KEY_ENABLED = "flutter.dm.capture.enabled"
        private const val KEY_PROMPT = "flutter.dm.notify.prompt.v1"
        private const val CHANNEL_ID = "dm_capture"

        private val AMOUNT_WITH_SYMBOL = Regex(
            """(?:₹|Rs\.?|INR|\$|€|£)\s?(\d[\d,]*(?:\.\d{1,2})?)""",
            RegexOption.IGNORE_CASE,
        )
        private val AMOUNT_AFTER_WORD = Regex(
            """(?:debited|credited|spent|paid|sent|received|withdrawn|deposited)[^\d]{0,24}(\d[\d,]*(?:\.\d{1,2})?)""",
            RegexOption.IGNORE_CASE,
        )

        private val PAYMENT_HINTS = listOf(
            "debited", "credited", "spent", "paid", "payment", "received",
            "sent", "withdrawn", "deposited", "order", "bill", "cashback",
            "refund", "purchase", "transaction",
        )
        private val INCOME_HINTS = listOf(
            "credited", "received", "cashback", "refund", "deposited",
        )
        private val SKIP_HINTS = listOf(
            "otp", "verification code", "do not share", "one-time password",
            "login code", "is your code",
        )
        private val BLOCKED_PACKAGES = setOf(
            "com.dailymoney.app",
            "com.android.systemui",
            "com.android.settings",
            "com.android.launcher",
            "com.google.android.apps.nexuslauncher",
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn?.notification ?: return
        val pkg = sbn.packageName ?: return
        if (pkg in BLOCKED_PACKAGES) return

        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return

        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)
            ?.toString()?.trim().orEmpty()
        val big = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?.toString()?.trim().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)
            ?.toString()?.trim().orEmpty()
        val sub = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)
            ?.toString()?.trim().orEmpty()

        val body = if (big.isNotEmpty()) big else text
        val haystack = listOf(title, body, sub)
            .filter { it.isNotEmpty() }
            .joinToString(" ")
            .replace(Regex("\\s+"), " ")
            .trim()
        if (haystack.length < 4) return

        val lower = haystack.lowercase()
        if (PAYMENT_HINTS.none { lower.contains(it) }) return
        if (SKIP_HINTS.any { lower.contains(it) }) return

        val amount = extractAmount(haystack) ?: return
        if (amount <= 0) return

        val now = System.currentTimeMillis()
        val signature = "$pkg|$amount|${title.take(40)}"
        if (SecureCaptureQueue.isDuplicate(this, signature, now)) return

        val label = appLabel(pkg)
        val type = if (INCOME_HINTS.any { lower.contains(it) }) "income" else "expense"
        val detection = JSONObject().apply {
            put("id", UUID.randomUUID().toString())
            put("packageName", pkg)
            put("appLabel", label)
            put("title", title.ifEmpty { label })
            put("text", haystack.take(300))
            put("amount", amount)
            put("type", type)
            put("capturedAt", Instant.ofEpochMilli(now).toString())
        }
        enqueue(detection)
        // The review prompt is a notification. Respect the separate
        // notification choice even while payment detection stays enabled.
        if (prefs.getBoolean(KEY_PROMPT, false)) {
            promptReview(label, amount, type)
        }
    }

    private fun extractAmount(text: String): Double? {
        val match = AMOUNT_WITH_SYMBOL.find(text)
            ?: AMOUNT_AFTER_WORD.find(text)
            ?: return null
        val raw = match.groupValues[1].replace(",", "")
        return raw.toDoubleOrNull()
    }

    private fun enqueue(detection: JSONObject) {
        SecureCaptureQueue.append(this, detection.toString())
    }

    private fun appLabel(pkg: String): String = try {
        val info = packageManager.getApplicationInfo(pkg, 0)
        packageManager.getApplicationLabel(info).toString()
    } catch (_: Exception) {
        pkg
    }

    private fun promptReview(label: String, amount: Double, type: String) {
        try {
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                !manager.areNotificationsEnabled()
            ) {
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Detected payments",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = "Payments found in other apps, waiting for review"
                }
                manager.createNotificationChannel(channel)
            }

            val launch = packageManager.getLaunchIntentForPackage(packageName)
                ?: return
            launch.flags = launch.flags or
                android.content.Intent.FLAG_ACTIVITY_NEW_TASK
            val pending = PendingIntent.getActivity(
                this,
                0,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val verb = if (type == "income") "received" else "spent"
            val text = "%s %s · tap to review".format(
                formatMoney(amount),
                verb,
            )

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }
            val notification = builder
                .setSmallIcon(R.drawable.ic_stat_wallet)
                .setContentTitle("Payment detected in $label")
                .setContentText(text)
                .setStyle(Notification.BigTextStyle().bigText(text))
                .setAutoCancel(true)
                .setContentIntent(pending)
                .build()

            manager.notify((System.currentTimeMillis() % 100000).toInt(), notification)
        } catch (_: Exception) {
            // Notification permission may be missing; detection still works.
        }
    }

    private fun formatMoney(value: Double): String {
        val rounded = Math.round(value * 100.0) / 100.0
        val whole = rounded.toLong()
        val paise = Math.round((rounded - whole) * 100).toInt()
        return if (paise == 0) "₹$whole" else "₹$whole.${paise.toString().padStart(2, '0')}"
    }
}
