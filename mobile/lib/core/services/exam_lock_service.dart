import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pengaman mode ujian di sisi perangkat (Android).
///
/// - `setSecure(true)`: pasang `FLAG_SECURE` — blokir screenshot & rekaman
///   layar, sembunyikan konten di recent apps. Dilepas saat ujian selesai.
/// - `setObscuredTouchBlocked(true)`: tolak sentuhan yang tertutup overlay /
///   aplikasi floating (anti-tapjacking) via `filterTouchesWhenObscured`.
/// - `isInMultiWindowMode()`: deteksi split-screen selama ujian.
/// - Pin standar (`startPin`): kunci HP di aplikasi ini. Tanpa device-owner
///   Android menampilkan dialog izin sekali; pelepasan paksa oleh user
///   terdeteksi (`isPinned`) dan dicatat sebagai pelanggaran.
/// - `getBatteryLevel()`: baterai 0-100 (/-1 bila tak terbaca).
///
/// Semua pemanggilan aman di platform non-Android (no-op / false / -1) dan
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

  /// Minta pin standar. Mengembalikan true bila native menerima
  /// (dialog izin sistem tetap bisa ditolak user — bukan kegagalan).
  static Future<bool> startPin() async {
    try {
      await _channel.invokeMethod('startLockTask');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamLock] startPin gagal: $e');
      return false;
    }
  }

  static Future<void> stopPin() async {
    try {
      await _channel.invokeMethod('stopLockTask');
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamLock] stopPin gagal: $e');
    }
  }

  /// True bila aplikasi sedang di-pin.
  static Future<bool> isPinned() async {
    try {
      final res = await _channel.invokeMethod<bool>('isInLockTaskMode');
      return res ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamLock] isPinned gagal: $e');
      return false;
    }
  }

  /// Level baterai 0-100, atau -1 bila tak terbaca / non-Android.
  static Future<int> getBatteryLevel() async {
    try {
      final res = await _channel.invokeMethod<int>('getBatteryLevel');
      return res ?? -1;
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamLock] getBatteryLevel gagal: $e');
      return -1;
    }
  }

  /// Aktifkan seluruh pengaman saat pengerjaan ujian dimulai.
  /// Pin paling akhir agar izin sistem muncul setelah sesi siap.
  static Future<void> lock() async {
    await setSecure(true);
    await setObscuredTouchBlocked(true);
    await startPin();
  }

  /// Lepaskan seluruh pengaman (submit / keluar / batal). Wajib dipanggil
  /// di semua jalur keluar agar FLAG_SECURE/pin tidak bocor ke layar lain.
  static Future<void> unlock() async {
    await stopPin();
    await setSecure(false);
    await setObscuredTouchBlocked(false);
  }
}
