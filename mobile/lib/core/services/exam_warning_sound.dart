import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:volume_controller/volume_controller.dart';

/// Bunyi peringatan kecurangan mode ujian (`public/sound/exam-warning.mp3`).
///
/// - [prime] dipanggil saat sesi ujian dimulai: player disiapkan + source
///   di-load di awal agar bunyi langsung keluar saat dipicu (bahkan bila
///   app sedang kehilangan fokus).
/// - [playDeterrent] dipanggil SETIAP app kehilangan fokus saat ujian
///   (cooldown 10 detik agar tidak spam).
/// - [playLimitWarning] dipanggil saat pelanggaran mencapai limit
///   (sekali per sesi, tepat sebelum auto-submit).
/// Semua best-effort: kegagalan tidak boleh mengganggu alur ujian.
/// Catatan: mode senyap/DND HP tetap membisukan suara (batasan OS).
class ExamWarningSound {
  static const _asset = 'public/sound/exam-warning.mp3';
  static AudioPlayer? _player;
  static bool _primed = false;
  static bool _limitPlayed = false;
  static DateTime? _lastPlay;

  static const _deterrentCooldown = Duration(seconds: 10);

  /// Maksimalkan volume perangkat tanpa panel sistem.
  static Future<void> maxVolume() async {
    try {
      final vc = VolumeController.instance;
      vc.showSystemUI = false;
      await vc.setVolume(1.0);
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamWarning] setVolume gagal: $e');
    }
  }

  /// Siapkan player + preload audio di awal sesi ujian.
  static Future<void> prime() async {
    try {
      await dispose();
      final player = AudioPlayer();
      _player = player;
      await player.setVolume(1.0);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSourceAsset(_asset);
      _primed = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamWarning] prime gagal: $e');
      _primed = false;
    }
  }

  static Future<void> _playNow() async {
    try {
      final player = _player;
      if (player == null || !_primed) {
        final fallback = AudioPlayer();
        _player = fallback;
        await fallback.setVolume(1.0);
        await fallback.setReleaseMode(ReleaseMode.stop);
        await fallback.play(AssetSource(_asset));
      } else {
        await player.resume();
      }
      _lastPlay = DateTime.now();
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamWarning] play gagal: $e');
    }
  }

  /// Bunyi peringatan tiap kehilangan fokus (ada cooldown).
  static Future<void> playDeterrent() async {
    final last = _lastPlay;
    if (last != null &&
        DateTime.now().difference(last) < _deterrentCooldown) {
      return;
    }
    await maxVolume();
    await ExamWarningSound._playNow();
  }

  /// Bunyi saat limit tercapai: selalu bunyi (sekali per sesi).
  static Future<void> playLimitWarning() async {
    if (_limitPlayed) return;
    _limitPlayed = true;
    await maxVolume();
    await ExamWarningSound._playNow();
  }

  /// Reset untuk sesi ujian berikutnya.
  static void reset() {
    _limitPlayed = false;
    _lastPlay = null;
  }

  static Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
    _primed = false;
  }
}
