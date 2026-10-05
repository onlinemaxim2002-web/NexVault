package com.cloudstorage.cloud_storage

import android.app.Activity
import com.android.billingclient.api.AlternativeBillingOnlyAvailabilityListener
import com.android.billingclient.api.AlternativeBillingOnlyInformationDialogListener
import com.android.billingclient.api.AlternativeBillingOnlyReportingDetailsListener
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClient.BillingResponseCode
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingResult
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Google Play "alternative billing only" (Play build). Before each UPI
 * payment: connect → check availability → Google's information screen →
 * a one-time externalTransactionToken that the server reports to Google
 * after the payment is approved. The payment itself is the normal UPI flow.
 *
 * Answers {status: ok, token} | {status: unavailable|cancelled|error, message}.
 */
object PlayBillingChannel {
    private var client: BillingClient? = null

    fun register(engine: FlutterEngine, activity: Activity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "cloudstorage/playbilling")
            .setMethodCallHandler { call, result ->
                if (call.method != "prepare") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                var answered = false
                val reply = { map: Map<String, Any?> ->
                    if (!answered) {
                        answered = true
                        activity.runOnUiThread { result.success(map) }
                    }
                }
                connect(activity) { connected ->
                    if (connected.responseCode != BillingResponseCode.OK) {
                        reply(fail("error", connected))
                    } else {
                        prepare(activity, reply)
                    }
                }
            }
    }

    private fun fail(status: String, r: BillingResult) =
        mapOf("status" to status, "message" to "${r.responseCode}: ${r.debugMessage}")

    private fun connect(activity: Activity, done: (BillingResult) -> Unit) {
        val existing = client
        if (existing != null && existing.isReady) {
            done(BillingResult.newBuilder().setResponseCode(BillingResponseCode.OK).build())
            return
        }
        val c = BillingClient.newBuilder(activity.applicationContext)
            .enableAlternativeBillingOnly()
            .build()
        client = c
        c.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) = done(billingResult)
            override fun onBillingServiceDisconnected() {
                client = null
            }
        })
    }

    private fun prepare(activity: Activity, reply: (Map<String, Any?>) -> Unit) {
        val c = client ?: return reply(mapOf("status" to "error", "message" to "not connected"))
        c.isAlternativeBillingOnlyAvailableAsync(AlternativeBillingOnlyAvailabilityListener { available ->
            if (available.responseCode != BillingResponseCode.OK) {
                reply(fail("unavailable", available))
                return@AlternativeBillingOnlyAvailabilityListener
            }
            activity.runOnUiThread {
                c.showAlternativeBillingOnlyInformationDialog(
                    activity,
                    AlternativeBillingOnlyInformationDialogListener { dialog ->
                        if (dialog.responseCode == BillingResponseCode.USER_CANCELED) {
                            reply(fail("cancelled", dialog))
                        } else if (dialog.responseCode != BillingResponseCode.OK) {
                            reply(fail("error", dialog))
                        } else {
                            c.createAlternativeBillingOnlyReportingDetailsAsync(
                                AlternativeBillingOnlyReportingDetailsListener { r, details ->
                                    val token = details?.externalTransactionToken
                                    if (r.responseCode == BillingResponseCode.OK && token != null) {
                                        reply(mapOf("status" to "ok", "token" to token))
                                    } else {
                                        reply(fail("error", r))
                                    }
                                },
                            )
                        }
                    },
                )
            }
        })
    }
}
