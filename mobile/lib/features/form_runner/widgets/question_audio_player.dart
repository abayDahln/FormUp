import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:form_up/core/services/auth_service.dart';

/// Pemutar audio soal - mendukung play ulang & seek ke durasi tertentu.
class QuestionAudioPlayer extends StatefulWidget {
  final String? url;
  final Uint8List? bytes;
  final String? label;

  const QuestionAudioPlayer({
    super.key,
    this.url,
    this.bytes,
    this.label,
  });

  @override
  State<QuestionAudioPlayer> createState() => _QuestionAudioPlayerState();
}

class _QuestionAudioPlayerState extends State<QuestionAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _loading = true;
  bool _seeking = false; // user sedang menggeser slider
  bool _toggling = false; // cegah double-tap tombol play
  Duration? _duration;
  Duration _position = Duration.zero;
  Source? _source; // sumber aktif — dipakai putar ulang saat resume gagal
  bool _completedOnce = false; // true sejak audio selesai sekali
  final List<StreamSubscription> _subs = [];
  bool _disposed = false; // listener tak boleh setState setelah ini
  int _seekGen = 0; // serial penomoran seek: hanya yang terbaru diterapkan

  bool get _alive => mounted && !_disposed;

  @override
  void initState() {
    super.initState();
    _prepareSource();
    _subs.addAll([
      _player.onPlayerStateChanged.listen((state) {
        if (_alive) setState(() => _playing = state == PlayerState.playing);
      }),
      _player.onDurationChanged.listen((d) {
        if (_alive) setState(() => _duration = d);
      }),
      _player.onPositionChanged.listen((p) {
        if (_alive && !_seeking) setState(() => _position = p);
      }),
      _player.onPlayerComplete.listen((_) async {
        // Kembalikan posisi ke awal lalu pause, sehingga tombol play
        // siap memutar ulang. Tandai completed: resume() dari state ini
        // adalah no-op diam-diam di Android — _toggle menanganinya.
        _completedOnce = true;
        try {
          await _player.seek(Duration.zero);
        } catch (_) {}
        if (!_alive) return;
        try {
          await _player.pause();
        } catch (_) {}
        if (_alive) {
          setState(() {
            _playing = false;
            _position = Duration.zero;
          });
        }
      }),
    ]);
  }

  Future<void> _prepareSource() async {
    try {
      if (widget.bytes != null) {
        _source = BytesSource(widget.bytes!);
      } else if (widget.url != null) {
        _source = UrlSource(profileImageUrl(widget.url!));
      }
      final src = _source;
      if (src != null) await _player.setSource(src);
    } finally {
      if (_alive) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _seekGen++; // batalkan seek yang masih berjalan
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading || _toggling) return;
    if (_playing) {
      await _player.pause();
      return;
    }
    _toggling = true;
    try {
      // Setelah audio selesai sekali: seek dulu ke posisi saat ini
      // (awal bila belum digeser) karena resume() dari state
      // completed/stopped tidak berefek di Android.
      if (_completedOnce) {
        try {
          await _player.seek(_position);
        } catch (_) {}
      }
      try {
        await _player.resume();
      } catch (_) {
        await _replay();
        return;
      }
      // Verifikasi ganda: resume() bisa gagal DIAM-DIAM (tanpa throw).
      // Flag _playing (via listener) bisa basi, jadi bandingkan juga
      // posisi: bila tak jalan DAN posisi tak maju → putar ulang source.
      final posBefore = _position;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!_alive) return;
      if (!_playing && !_loading && !_seeking && _position == posBefore) {
        await _replay();
      }
    } finally {
      _toggling = false;
    }
  }

  /// Putar ulang source dari awal — jalan terakhir paling andal.
  Future<void> _replay() async {
    final src = _source;
    if (src == null || !_alive) return;
    try {
      await _player.play(src);
      _completedOnce = false;
    } catch (_) {
      if (_alive) setState(() => _playing = false);
    }
  }

  Future<void> _onSeek(Duration target) async {
    // Serial: geser-cepat hanya menerapkan target TERAKHIR.
    final gen = ++_seekGen;
    try {
      await _player.seek(target);
    } catch (_) {
      return;
    }
    if (!_alive || gen != _seekGen) return;
    setState(() => _position = target);
  }


  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxMs = (_duration ?? Duration.zero).inMilliseconds;
    final posMs = _position.inMilliseconds.clamp(0, maxMs).toDouble();
    final progress = maxMs == 0 ? 0.0 : (posMs / maxMs).clamp(0.0, 1.0);
    final hasDuration = maxMs > 0;
    // Kontras adaptif: teks gelap di mode terang, terang di mode gelap.
    final titleColor = cs.onSurface;
    final subtitleColor = cs.onSurfaceVariant;
    final trackColor = cs.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border.all(color: cs.primary, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _loading
          ? Row(
              children: [
                 SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mempersiapkan pratinjau audio',
                        style: TextStyle(
                          fontSize: 12,
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.label != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.label!,
                          style: TextStyle(
                            fontSize: 11,
                            color: subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                InkResponse(
                  onTap: _toggle,
                  radius: 26,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: cs.onPrimary,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audio Soal',
                        style: TextStyle(
                          fontSize: 12,
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.label != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.label!,
                          style: TextStyle(
                            fontSize: 11,
                            color: subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      // Slider agar posisi audio bisa digeser bebas
                      if (hasDuration)
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape:
                                const RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape:
                                const RoundSliderOverlayShape(overlayRadius: 12),
                            padding: EdgeInsets.zero,
                          ),
                          child: Slider(
                            value: posMs,
                            max: maxMs.toDouble(),
                            onChangeStart: (_) {
                              if (mounted) setState(() => _seeking = true);
                            },
                            onChanged: (value) {
                              if (mounted) {
                                setState(() =>
                                    _position = Duration(milliseconds: value.round()));
                              }
                            },
                            onChangeEnd: (value) async {
                              await _onSeek(Duration(milliseconds: value.round()));
                              if (mounted) setState(() => _seeking = false);
                            },
                            activeColor: cs.primary,
                            inactiveColor: trackColor,
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 4,
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: trackColor,
                              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_fmt(_position)} / ${hasDuration ? _fmt(_duration!) : '--:--'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}
