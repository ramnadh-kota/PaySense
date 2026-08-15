package com.example.paysense

import android.content.Context
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth's
// biometric prompt on Android.
class MainActivity : FlutterFragmentActivity() {
    private val smsChannelName = "paysense/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The only bridge between the native SmsReceiver's pending-event
        // store and Dart's SmsTransactionProcessor — deliberately just
        // fetch/acknowledge, no parsing or business logic on either side
        // of this channel.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingEvents" -> result.success(getPendingEvents())
                    "acknowledgeEvents" -> {
                        @Suppress("UNCHECKED_CAST")
                        val nativeIds = call.argument<List<String>>("nativeIds") ?: emptyList()
                        acknowledgeEvents(nativeIds)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getPendingEvents(): List<Map<String, Any?>> {
        val prefs = getSharedPreferences(SmsReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val events = SmsReceiver.readEvents(prefs)
        val result = mutableListOf<Map<String, Any?>>()
        for (i in 0 until events.length()) {
            val obj = events.getJSONObject(i)
            result.add(
                mapOf(
                    "nativeId" to obj.getString("nativeId"),
                    "sender" to obj.getString("sender"),
                    "body" to obj.getString("body"),
                    "timestampMillis" to obj.getLong("timestampMillis"),
                )
            )
        }
        return result
    }

    private fun acknowledgeEvents(nativeIds: List<String>) {
        val prefs = getSharedPreferences(SmsReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val events = SmsReceiver.readEvents(prefs)
        val remaining = JSONArray()
        for (i in 0 until events.length()) {
            val obj = events.getJSONObject(i)
            if (!nativeIds.contains(obj.getString("nativeId"))) {
                remaining.put(obj)
            }
        }
        prefs.edit().putString(SmsReceiver.PENDING_EVENTS_KEY, remaining.toString()).apply()
    }
}
