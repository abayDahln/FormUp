package com.example.form_up

import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "formup/exam_lock"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // FLAG_SECURE: blokir screenshot & rekaman layar + sembunyikan
                // konten di recent apps selama mode ujian.
                "setSecure" -> {
                    val secure = call.argument<Boolean>("secure") ?: false
                    runOnUiThread {
                        try {
                            if (secure) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SECURE_FAILED", e.message, null)
                        }
                    }
                }
                // Tolak sentuhan yang tertutup overlay / aplikasi floating
                // (anti-tapjacking) selama mode ujian.
                "setObscuredTouchBlocked" -> {
                    val blocked = call.argument<Boolean>("blocked") ?: false
                    runOnUiThread {
                        try {
                            window.decorView.filterTouchesWhenObscured = blocked
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OBSCURED_FAILED", e.message, null)
                        }
                    }
                }
                // Deteksi split-screen / multi-window (API 24+).
                "isInMultiWindowMode" -> {
                    try {
                        val inMulti = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInMultiWindowMode
                        result.success(inMulti)
                    } catch (e: Exception) {
                        result.error("MULTIWINDOW_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
