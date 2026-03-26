package com.example.ghost_chat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

class OverlayActivity : FlutterActivity() {

    companion object {
        // BUG 2 FIX: Keep a WeakRef so MainActivity can finish this activity
        var instance: WeakReference<OverlayActivity>? = null
    }

    override fun onStart() {
        super.onStart()
        instance = WeakReference(this)
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    override fun getDartEntrypointFunctionName(): String {
        return "overlayMain" // ✅ explicitly runs overlayMain() from main.dart
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MainActivity.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "closeOverlay" -> {
                        finish()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
        finish() // ✅ back button closes Ghost Chat
    }
}
