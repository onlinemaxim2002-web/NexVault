package com.cloudstorage.cloud_storage

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * UPI Intent payments.
 *
 * The result handler lives here, at activity level, so the UPI app's answer is
 * caught even when Android killed our process while the UPI app was open (the
 * activity is recreated and onActivityResult is delivered to it). The order id
 * is saved before the UPI app opens and the raw answer is saved the moment it
 * arrives; Dart sends it to the server and only then deletes it (see
 * lib/services/payments.dart).
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    private val store get() = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "launch" -> {
                        val orderId = call.argument<String>("orderId")
                        val uri = call.argument<String>("uri")
                        if (orderId.isNullOrEmpty() || uri.isNullOrEmpty()) {
                            result.error("BAD_ARGS", "orderId and uri are required", null)
                        } else {
                            launch(orderId, uri, result)
                        }
                    }
                    "pending" -> result.success(pendingAnswers())
                    "launchedOrder" -> result.success(store.getString(KEY_LAUNCHED, null))
                    "clear" -> {
                        val orderId = call.argument<String>("orderId") ?: ""
                        removeAnswer(orderId)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun launch(orderId: String, uri: String, result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri))
        val apps = if (Build.VERSION.SDK_INT >= 33) {
            packageManager.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(intent, 0)
        }
        if (apps.isEmpty()) {
            result.error("NO_UPI_APP", "No UPI app is installed", null)
            return
        }
        // Persist the order id BEFORE leaving the app.
        store.edit().putString(KEY_LAUNCHED, orderId).commit()
        try {
            startActivityForResult(Intent.createChooser(intent, "Pay with"), REQUEST_UPI)
            result.success(true)
        } catch (e: Exception) {
            store.edit().remove(KEY_LAUNCHED).commit()
            result.error("NO_UPI_APP", e.message, null)
        }
    }

    @Deprecated("Activity result API is not available to FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_UPI) {
            val orderId = store.getString(KEY_LAUNCHED, null)
            if (orderId != null) {
                saveAnswer(orderId, rawAnswer(data))
                store.edit().remove(KEY_LAUNCHED).commit()
                // If Flutter is running, tell it to send the answer now; otherwise
                // it is picked up from storage when the app starts.
                channel?.invokeMethod("answer", orderId)
            }
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    /** "response" extra, else any extra containing "Status=", else Status=NO_RESPONSE. */
    private fun rawAnswer(data: Intent?): String {
        val extras = data?.extras ?: return "Status=NO_RESPONSE"
        data.getStringExtra("response")?.takeIf { it.isNotBlank() }?.let { return it }
        for (key in extras.keySet()) {
            @Suppress("DEPRECATION")
            val value = extras.get(key)?.toString() ?: continue
            if (value.contains("Status=", ignoreCase = true)) return value
        }
        return "Status=NO_RESPONSE"
    }

    private fun answers(): JSONObject =
        try { JSONObject(store.getString(KEY_ANSWERS, "{}") ?: "{}") } catch (_: Exception) { JSONObject() }

    @Synchronized
    private fun saveAnswer(orderId: String, raw: String) {
        val all = answers()
        all.put(orderId, JSONObject().put("raw", raw).put("at", System.currentTimeMillis()))
        store.edit().putString(KEY_ANSWERS, all.toString()).commit()
    }

    @Synchronized
    private fun removeAnswer(orderId: String) {
        val all = answers()
        all.remove(orderId)
        store.edit().putString(KEY_ANSWERS, all.toString()).commit()
    }

    /** {orderId: {"raw": "...", "at": millis}} as a JSON string. */
    private fun pendingAnswers(): String = answers().toString()

    companion object {
        private const val CHANNEL = "cloudstorage/upi"
        private const val PREFS = "upi_payments"
        private const val KEY_LAUNCHED = "launched_order"
        private const val KEY_ANSWERS = "answers"
        private const val REQUEST_UPI = 7301
    }
}
