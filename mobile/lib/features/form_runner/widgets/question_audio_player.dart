import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Pemutar audio soal
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
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _playing = false;
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
      await _player.resume();
    }
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7FFFD), Color(0xFFE6F8F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7ECFC0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A018081),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
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
                        "Mempersiapkan pratinjau audio",
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
                    decoration: BoxDecoration(
                      color: const Color(0xFF018081),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x2A018081),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
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
                        "Audio Soal",
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
                  '${_fmt(_position)} / ${maxMs == 0 ? '--:--' : _fmt(_duration!)}',
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
