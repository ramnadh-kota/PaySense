package com.example.paysense

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.provider.Telephony
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * Captures incoming SMS and persists the minimum fields PaySense needs
 * (sender, body, timestamp) to SharedPreferences, so the Flutter side can
 * process them the next time it runs. This must work whether the app is
 * open, backgrounded, or fully closed — it deliberately does nothing
 * beyond persisting: no parsing, no wallet matching, no financial writes.
 * All of that lives in Dart (SmsTransactionProcessor), never here.
 */
class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages == null || messages.isEmpty()) {
            return
        }

        // A single logical SMS can arrive as multiple SmsMessage parts
        // sharing one sender/timestamp — concatenate their bodies back
        // into one message rather than persisting fragments separately.
        val sender = messages[0].originatingAddress ?: return
        val timestampMillis = messages[0].timestampMillis
        val body = messages.joinToString(separator = "") { it.messageBody ?: "" }

        if (body.isBlank()) {
            return
        }

        appendPendingEvent(context, sender, body, timestampMillis)
    }

    private fun appendPendingEvent(
        context: Context,
        sender: String,
        body: String,
        timestampMillis: Long,
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = readEvents(prefs)

        val event = JSONObject()
        event.put("nativeId", UUID.randomUUID().toString())
        event.put("sender", sender)
        event.put("body", body)
        event.put("timestampMillis", timestampMillis)
        existing.put(event)

        // Bound the queue so a device that never reopens PaySense can't
        // grow this file unboundedly — oldest events are dropped first.
        val trimmed = JSONArray()
        val start = if (existing.length() > MAX_PENDING_EVENTS) {
            existing.length() - MAX_PENDING_EVENTS
        } else {
            0
        }
        for (i in start until existing.length()) {
            trimmed.put(existing.get(i))
        }

        prefs.edit().putString(PENDING_EVENTS_KEY, trimmed.toString()).apply()
    }

    companion object {
        const val PREFS_NAME = "paysense_sms_prefs"
        const val PENDING_EVENTS_KEY = "pending_sms_events"
        const val MAX_PENDING_EVENTS = 200

        /** Shared with MainActivity's MethodChannel handler. */
        fun readEvents(prefs: SharedPreferences): JSONArray {
            val raw = prefs.getString(PENDING_EVENTS_KEY, null) ?: return JSONArray()
            return try {
                JSONArray(raw)
            } catch (e: Exception) {
                JSONArray()
            }
        }
    }
}
