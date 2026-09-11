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

  static Future<bool> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod('setSecure', {'secure': secure});
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamLock] setSecure gagal: $e');
      return false;
    }
  }

  static Future<bool> setObscuredTouchBlocked(bool blocked) async {
    try {
      await _channel.invokeMethod('setObscuredTouchBlocked', {'blocked': blocked});
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamLock] setObscuredTouchBlocked gagal: $e');
      return false;
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
  /// Mengembalikan status per-lapisan — caller WAJIB memberi tahu user
  /// bila ada lapisan yang gagal (jangan diam seolah terkunci penuh).
  static Future<ExamLockState> lock() async {
    final secure = await setSecure(true);
    final touch = await setObscuredTouchBlocked(true);
    final pinned = await startPin();
    return ExamLockState(
        secure: secure, touchBlocked: touch, pinned: pinned);
  }

  /// Lepaskan seluruh pengaman (submit / keluar / batal). Wajib dipanggil
  /// di semua jalur keluar agar FLAG_SECURE/pin tidak bocor ke layar lain.
  /// Mengembalikan true bila semua lapisan berhasil dilepas.
  static Future<bool> unlock() async {
    var ok = true;
    try {
      await _channel.invokeMethod('stopLockTask');
    } catch (e) {
      ok = false;
      if (kDebugMode) debugPrint('[ExamLock] stopPin gagal: $e');
    }
    ok = await setSecure(false) && ok;
    ok = await setObscuredTouchBlocked(false) && ok;
    return ok;
  }
}

/// Status per-lapisan pengaman ujian — agar kegagalan satu lapisan
/// terlihat jelas, bukan ditelan diam-diam.
class ExamLockState {
  final bool secure;
  final bool touchBlocked;
  final bool pinned;

  const ExamLockState({
    this.secure = false,
    this.touchBlocked = false,
    this.pinned = false,
  });

  bool get fullyLocked => secure && touchBlocked && pinned;

  /// Lapisan yang gagal aktif, untuk pesan peringatan ke user/pengawas.
  List<String> get failedLayers {
    final out = <String>[];
    if (!secure) out.add('anti-screenshot');
    if (!touchBlocked) out.add('anti-overlay');
    if (!pinned) out.add('pin aplikasi');
    return out;
  }
}
