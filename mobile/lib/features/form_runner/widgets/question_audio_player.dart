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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _loading
          ? Row(
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Mempersiapkan pratinjau audio",
                        style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
                      ),
                      if (widget.label != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.label!,
                          style: const TextStyle(fontSize: 11, color: Colors.black45),
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
                IconButton(
                  onPressed: _toggle,
                  icon: Icon(
                    _playing ? Icons.pause_circle : Icons.play_circle,
                    color: kAuthPrimary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Audio Soal",
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      if (widget.label != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.label!,
                          style: const TextStyle(fontSize: 11, color: Colors.black45),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Slider(
                        value: maxMs == 0 ? 0 : posMs,
                        max: maxMs == 0 ? 1 : maxMs.toDouble(),
                        activeColor: kAuthPrimary,
                        onChanged: maxMs == 0
                            ? null
                            : (v) async {
                                final t = Duration(milliseconds: v.round());
                                await _player.seek(t);
                                setState(() => _position = t);
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  maxMs == 0 ? _fmt(_position) : _fmt(_duration!),
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
    );
  }
}
