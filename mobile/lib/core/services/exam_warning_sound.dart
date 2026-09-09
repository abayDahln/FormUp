import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  static bool _limitPlayed = false;
  static DateTime? _lastPlay;
  static Timer? _safetyTimer;

  /// Pengaman: hentikan loop maksimal 3 menit agar tidak bunyi selamanya
  /// bila user tak kunjung kembali (hemat baterai).
  static const _maxLoop = Duration(minutes: 3);

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

  /// Validasi dini asset audio di awal sesi ujian.
  /// Playback selalu memakai player + play() fresh (lihat [_playNow])
  /// karena resume() pada player yang belum pernah play() adalah no-op.
  static Future<void> prime() async {
    try {
      final probe = AudioPlayer();
      await probe.setVolume(1.0);
      await probe.setReleaseMode(ReleaseMode.stop);
      await probe.setSourceAsset(_asset);
      await probe.dispose();
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamWarning] prime gagal: $e');
    }
  }

  static Future<void> _playNow() async {
    try {
      // Selalu player + play() baru: dijamin mulai dari awal,
      // tidak tergantung state player sebelumnya. Mode LOOP agar
      // terus berbunyi selama user di luar form.
      try {
        await _player?.dispose();
      } catch (_) {}
      final player = AudioPlayer();
      _player = player;
      await player.setVolume(1.0);
      await player.setReleaseMode(ReleaseMode.loop);
      try {
        await player.play(AssetSource(_asset));
      } catch (_) {
        // Fallback: putar dari bytes (jalur native berbeda) bila
        // resolusi asset bermasalah di perangkat tertentu.
        final bytes = await rootBundle.load(_asset);
        await player.play(BytesSource(bytes.buffer.asUint8List()));
      }
      _lastPlay = DateTime.now();
      _armSafetyTimer();
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamWarning] play gagal: $e');
    }
  }

  static void _armSafetyTimer() {
    _safetyTimer?.cancel();
    _safetyTimer = Timer(_maxLoop, () {
      unawaited(stop());
    });
  }

  /// Hentikan bunyi (kembali ke form / submit manual / keluar ujian).
  static Future<void> stop() async {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    try {
      await _player?.stop();
    } catch (_) {}
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }

  /// Tes manual (tombol di pengaturan ujian): maksimalkan volume lalu
  /// putar bunyi. Mengembalikan null bila sukses, atau pesan error
  /// aslinya bila gagal — dipakai untuk diagnosis di HP.
  static Future<String?> testPlay() async {
    try {
      // Matikan loop lama dulu agar tidak menumpuk tak terhentikan.
      await stop();
      await maxVolume();
      final player = AudioPlayer();
      _player = player;
      await player.setVolume(1.0);
      await player.setReleaseMode(ReleaseMode.stop);
      try {
        await player.play(AssetSource(_asset));
      } catch (_) {
        final bytes = await rootBundle.load(_asset);
        await player.play(BytesSource(bytes.buffer.asUint8List()));
      }
      _lastPlay = DateTime.now();
      _armSafetyTimer();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// True bila loop bunyi sedang berjalan.
  static bool get isPlaying => _player?.state == PlayerState.playing;

  /// Pastikan alarm berbunyi (dipanggil berkala selama user di luar form).
  /// Memulihkan bila OS menjeda audio (fokus audio direbut notifikasi
  /// lain) — tanpa cooldown karena hanya jalan bila sedang sunyi.
  static Future<void> ensureLooping() async {
    if (isPlaying) return;
    await maxVolume();
    await ExamWarningSound._playNow();
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
  }
}
