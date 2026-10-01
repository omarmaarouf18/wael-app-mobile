package com.wael.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Screenshots, screen recording and the recent-apps thumbnail are
        // blocked while FLAG_SECURE is set. Dart turns it on only for the
        // protected video player screen and clears it when that screen closes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "isEnabled" -> {
                        val flags = window.attributes.flags
                        result.success(flags and WindowManager.LayoutParams.FLAG_SECURE != 0)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        const val SECURE_CHANNEL = "com.wael.app/secure_screen"
    }
}
