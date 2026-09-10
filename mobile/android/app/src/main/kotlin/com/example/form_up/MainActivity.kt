package com.example.form_up

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
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
                // Pin standar: kunci HP di aplikasi ini. Tanpa device-owner,
                // Android menampilkan dialog izin sekali; user bisa melepas
                // via Back+Recents — pelepasan terdeteksi dari Dart dan
                // dicatat sebagai pelanggaran + pin ulang otomatis.
                "startLockTask" -> {
                    runOnUiThread {
                        try {
                            startLockTask()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LOCKTASK_FAILED", e.message, null)
                        }
                    }
                }
                "stopLockTask" -> {
                    runOnUiThread {
                        try {
                            stopLockTask()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UNLOCKTASK_FAILED", e.message, null)
                        }
                    }
                }
                "isInLockTaskMode" -> {
                    try {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            am.lockTaskModeState
                        } else {
                            ActivityManager.LOCK_TASK_MODE_NONE
                        }
                        result.success(mode != ActivityManager.LOCK_TASK_MODE_NONE)
                    } catch (e: Exception) {
                        result.error("LOCKTASK_CHECK_FAILED", e.message, null)
                    }
                }
                // Level baterai 0-100 via sticky broadcast (tanpa permission).
                "getBatteryLevel" -> {
                    try {
                        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                        val status: Intent? = registerReceiver(null, filter)
                        val level = status?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                        val scale = status?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
                        if (level < 0 || scale <= 0) {
                            result.success(-1)
                        } else {
                            result.success((level * 100) / scale)
                        }
                    } catch (e: Exception) {
                        result.error("BATTERY_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
