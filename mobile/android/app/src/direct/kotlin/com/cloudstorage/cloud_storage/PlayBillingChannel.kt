package com.cloudstorage.cloud_storage

import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Direct (non-Play) build: no Google billing; the app never asks for it. */
object PlayBillingChannel {
    fun register(engine: FlutterEngine, activity: Activity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "cloudstorage/playbilling")
            .setMethodCallHandler { _, result -> result.success(mapOf("status" to "not_play")) }
    }
}
