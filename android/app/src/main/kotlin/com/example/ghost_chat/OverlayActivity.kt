package com.example.ghost_chat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class OverlayActivity : FlutterActivity() {

    override fun getDartEntrypointFunctionName(): String {
        return "overlayMain"  // ✅ explicitly runs overlayMain() from main.dart
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

    override fun onBackPressed() {
        finish()  // ✅ back button closes Ghost Chat
    }
}
