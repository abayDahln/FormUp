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

  /// Antrean serial play: dua pemicu bersamaan tak lagi membuat 2 player
  /// loop menumpuk — pemicu kedua antre, membuang hasil pertama.
  static Future<void> _playChain = Future.value();
  static int _playGen = 0;
  static bool _looping = false;

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

  static Future<void> _playNow() {
    // Serialkan: pemicu bersamaan antre, bukan menumpuk player.
    _playChain = _playChain.then((_) => _playNowInner()).catchError((_) {});
    return _playChain;
  }

  static Future<void> _playNowInner() async {
    final gen = _playGen;
    try {
      // Selalu player + play() baru: dijamin mulai dari awal,
      // tidak tergantung state player sebelumnya. Mode LOOP agar
      // terus berbunyi selama user di luar form.
      final stale = _player;
      _player = null;
      _looping = false;
      if (stale != null) {
        try {
          await stale.stop();
        } catch (_) {}
        try {
          await stale.dispose();
        } catch (_) {}
      }
      final player = AudioPlayer();
      _player = player;
      await player.setVolume(1.0);
      await player.setReleaseMode(ReleaseMode.loop);
      // Disusul play baru / stop di tengah jalan: buang diri.
      if (gen != _playGen) {
        try {
          await player.dispose();
        } catch (_) {}
        if (identical(_player, player)) _player = null;
        return;
      }
      try {
        await player.play(AssetSource(_asset));
      } catch (_) {
        // Fallback: putar dari bytes (jalur native berbeda) bila
        // resolusi asset bermasalah di perangkat tertentu.
        final bytes = await rootBundle.load(_asset);
        await player.play(BytesSource(bytes.buffer.asUint8List()));
      }
      if (gen != _playGen || !identical(_player, player)) {
        try {
          await player.stop();
        } catch (_) {}
        try {
          await player.dispose();
        } catch (_) {}
        return;
      }
      _looping = true;
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
    _playGen++; // batalkan play yang antre/berjalan
    _looping = false;
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
      _playGen++;
      _looping = false;
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

  /// True bila loop bunyi sedang berjalan (flag internal, bukan baca
  /// state sinkron yang tak andal).
  static bool get isPlaying => _looping && _player != null;

  /// Pastikan alarm berbunyi (dipanggil berkala selama user di luar form).
  /// Memulihkan bila OS menjeda audio (fokus audio direbut notifikasi
  /// lain) — tanpa cooldown karena hanya jalan bila sedang sunyi.
  static Future<void> ensureLooping() async {
    if (_looping && _player != null) {
      try {
        await _player!.resume();
      } catch (_) {}
      return;
    }
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
    _playGen++;
    _looping = false;
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
