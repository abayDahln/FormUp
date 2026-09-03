import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

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
  Duration? _duration;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _prepareSource();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted && !_seeking) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) async {
      // Kunci agar play ulang selalu berhasil: kembalikan posisi ke awal
      // lalu pause, sehingga player tidak tertahan di state stopped.
      await _player.seek(Duration.zero);
      await _player.pause();
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _prepareSource() async {
    try {
      if (widget.bytes != null) {
        await _player.setSource(BytesSource(widget.bytes!));
      } else if (widget.url != null) {
        await _player.setSource(UrlSource(profileImageUrl(widget.url!)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (_playing) {
      await _player.pause();
    } else {
      // Pastikan player aktif sebelum resume (aman untuk semua state).
      try {
        await _player.resume();
      } catch (_) {
        await _player.stop();
        await _player.seek(_position);
        await _player.resume();
      }
    }
  }

  Future<void> _onSeek(Duration target) async {
    await _player.seek(target);
    if (mounted) setState(() => _position = target);
  }


  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = (_duration ?? Duration.zero).inMilliseconds;
    final posMs = _position.inMilliseconds.clamp(0, maxMs).toDouble();
    final progress = maxMs == 0 ? 0.0 : (posMs / maxMs).clamp(0.0, 1.0);
    final hasDuration = maxMs > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: kAuthPrimary, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _loading
          ? Row(
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(kAuthPrimary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Mempersiapkan pratinjau audio',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF123B36),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.label != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.label!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1E6B60),
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
                    decoration: const BoxDecoration(
                      color: Color(0xFF018081),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Audio Soal',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF123B36),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.label != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.label!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1E6B60),
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
                            activeColor: kAuthPrimary,
                            inactiveColor: const Color(0xFFBFE9E1),
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
                              backgroundColor: const Color(0xFFBFE9E1),
                              valueColor: const AlwaysStoppedAnimation<Color>(kAuthPrimary),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_fmt(_position)} / ${hasDuration ? _fmt(_duration!) : '--:--'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF123B36),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}
