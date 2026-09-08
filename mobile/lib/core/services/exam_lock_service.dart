import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pengaman mode ujian di sisi perangkat (Android).
///
/// - `setSecure(true)`: pasang `FLAG_SECURE` — blokir screenshot & rekaman
///   layar, sembunyikan konten di recent apps. Dilepas saat ujian selesai.
/// - `setObscuredTouchBlocked(true)`: tolak sentuhan yang tertutup overlay /
///   aplikasi floating (anti-tapjacking) via `filterTouchesWhenObscured`.
/// - `isInMultiWindowMode()`: deteksi split-screen selama ujian.
///
/// Semua pemanggilan aman di platform non-Android (no-op / false) dan
/// tidak pernah melempar — kegagalan native tidak boleh menghentikan ujian.
class ExamLockService {
  static const _channel = MethodChannel('formup/exam_lock');

  static Future<void> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod('setSecure', {'secure': secure});
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamLock] setSecure gagal: $e');
    }
  }

  static Future<void> setObscuredTouchBlocked(bool blocked) async {
    try {
      await _channel.invokeMethod('setObscuredTouchBlocked', {'blocked': blocked});
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamLock] setObscuredTouchBlocked gagal: $e');
    }
  }

  static Future<bool> isInMultiWindowMode() async {
    try {
      final res = await _channel.invokeMethod<bool>('isInMultiWindowMode');
      return res ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamLock] isInMultiWindowMode gagal: $e');
      return false;
    }
  }

  /// Aktifkan seluruh pengaman saat pengerjaan ujian dimulai.
  static Future<void> lock() async {
    await setSecure(true);
    await setObscuredTouchBlocked(true);
  }

  /// Lepaskan seluruh pengaman (submit / keluar / batal). Wajib dipanggil
  /// di semua jalur keluar agar FLAG_SECURE tidak bocor ke layar lain.
  static Future<void> unlock() async {
    await setSecure(false);
    await setObscuredTouchBlocked(false);
  }
}
