import 'dart:async';

import 'package:flutter/foundation.dart';

/// Mesin efek ketik untuk bubble AI yang sedang streaming.
///
/// Chunk dari SSE sering datang dalam burst besar (beberapa kalimat
/// sekaligus), sehingga teks tampak "melompat" dan user tidak bisa
/// membedakan AI benar-benar mengetik atau hang. TypingStream menampung
/// teks mentah lalu membuangnya ke notifier [out] sedikit demi sedikit
/// (per batas kata) sehingga terlihat seperti diketik satu per satu.
///
/// Kecepatannya adaptif: makin besar backlog (AI mengirim lebih cepat
/// dari ketikan), makin banyak karakter per tick — menjamin ketikan
/// selalu berhasil mengejar sebelum respons selesai.
class TypingStream {
  TypingStream(this.out, {this.onTick});

  /// Notifier yang dirender StreamingAiText.
  final ValueNotifier<String> out;

  /// Dipanggil tiap kali teks tampil bertambah (untuk auto-scroll).
  final void Function()? onTick;

  final StringBuffer _target = StringBuffer();
  int _shownLen = 0;
  Timer? _timer;
  Completer<void>? _drained;
  bool _finished = false;

  /// Teks yang sudah "diketik" (prefix dari target).
  String get shownText {
    final t = _target.toString();
    return t.substring(0, _shownLen.clamp(0, t.length));
  }

  bool get isCaughtUp => _shownLen >= _target.length;

  /// Tambah chunk mentah (boleh burst besar).
  void add(String chunk) {
    if (_finished && isCaughtUp) return;
    _target.write(chunk);
    _ensureTimer();
  }

  /// Dipanggil saat stream data selesai — Future resolve ketika semua
  /// teks sudah selesai "diketik" ke layar.
  Future<void> finish() {
    _finished = true;
    if (isCaughtUp) return Future.value();
    _drained ??= Completer<void>();
    _ensureTimer();
    return _drained!.future;
  }

  /// Hentikan mesin (stop user / ganti sesi / screen dibuang).
  /// Aman dipanggil lebih dari sekali.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (_drained != null && !_drained!.isCompleted) {
      _drained!.complete();
    }
    _drained = null;
  }

  void _ensureTimer() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
  }

  void _tick() {
    final target = _target.toString();
    if (_shownLen >= target.length) {
      // Sudah kejar ketertinggalan — berhenti hemat resource.
      _timer?.cancel();
      _timer = null;
      if (_drained != null && !_drained!.isCompleted) {
        _drained!.complete();
      }
      _drained = null;
      return;
    }
    final backlog = target.length - _shownLen;
    // Adaptif: per kata saat backlog kecil; seret lebih banyak karakter
    // per tick saat datang lebih cepat dari ketikan.
    final int step;
    if (backlog > 1200) {
      step = 96;
    } else if (backlog > 600) {
      step = 48;
    } else if (backlog > 250) {
      step = 18;
    } else if (backlog > 80) {
      step = 8;
    } else {
      step = 4;
    }
    var end = (_shownLen + step).clamp(0, target.length);
    if (end < target.length) {
      // Geser ujung ketikan ke batas kata berikutnya agar potongan rapi
      // (tidak memotong di tengah kata lebih dari yang perlu).
      final lookEnd = (end + 16).clamp(0, target.length);
      final m = RegExp(r'\s').firstMatch(target.substring(end, lookEnd));
      if (m != null) end += m.end;
    }
    _shownLen = end;
    out.value = target.substring(0, end);
    onTick?.call();
  }
}
