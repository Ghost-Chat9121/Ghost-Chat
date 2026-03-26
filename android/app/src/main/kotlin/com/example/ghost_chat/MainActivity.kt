package com.example.ghost_chat

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        // BUG 1 FIX: Single source of truth for channel names
        const val CHANNEL = "ghost_chat/overlay"
        const val FOREGROUND_CHANNEL = "com.example.ghost_chat/foreground_service"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Overlay control channel ────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchOverlay" -> {
                        val intent = Intent(this, OverlayActivity::class.java)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    }
                    // BUG 2 FIX: Delegate close to the OverlayActivity via WeakRef
                    "closeOverlay" -> {
                        OverlayActivity.instance?.get()?.finish()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // BUG 1 FIX: Register the foreground service channel so screen-share works on Android 14+
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        try {
                            val intent = Intent(this, ScreenShareService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SERVICE_ERROR", e.message, null)
                        }
                    }
                    "stopService" -> {
                        try {
                            stopService(Intent(this, ScreenShareService::class.java))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SERVICE_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
