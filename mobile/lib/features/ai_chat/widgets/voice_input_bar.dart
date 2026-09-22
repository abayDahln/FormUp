import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bilah input mode rekam suara ala Gemini (pill gelap):
/// [+] [gelombang suara .........] [stop] [kirim].
///
/// - Tengah: deretan titik yang memanjang menjadi gelombang mengikuti
///   [levelStream] (0..1, dari amplitudo mikrofon). Saat hening, tampil
///   titik-titik kecil dengan gerakan halus agar terasa hidup.
/// - Tombol kotak = selesai merekam ([onStop]); tombol panah biru = kirim
///   ([onSend]).
class VoiceInputBar extends StatefulWidget {
  /// Aliran level suara 0..1. Null = animasi idle saja.
  final Stream<double>? levelStream;

  final VoidCallback onPickFiles;
  final VoidCallback onStop;
  final VoidCallback onSend;
  final bool canSend;
  final bool actionsEnabled;

  const VoiceInputBar({
    super.key,
    this.levelStream,
    required this.onPickFiles,
    required this.onStop,
    required this.onSend,
    this.canSend = false,
    this.actionsEnabled = true,
  });

  @override
  State<VoiceInputBar> createState() => _VoiceInputBarState();
}

class _VoiceInputBarState extends State<VoiceInputBar>
    with SingleTickerProviderStateMixin {
  static const _bars = 24;

  late final AnimationController _phase;
  final List<double> _levels = List.filled(_bars, 0.0);
  StreamSubscription<double>? _sub;
  double _smooth = 0.0;

  @override
  void initState() {
    super.initState();
    _phase = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _subscribe(widget.levelStream);
  }

  @override
  void didUpdateWidget(covariant VoiceInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.levelStream != widget.levelStream) {
      _subscribe(widget.levelStream);
    }
  }

  void _subscribe(Stream<double>? stream) {
    _sub?.cancel();
    _sub = null;
    if (stream == null) return;
    _sub = stream.listen((v) {
      final clamped = v.isNaN ? 0.0 : v.clamp(0.0, 1.0);
      // Haluskan agar gelombang tidak patah-patah.
      _smooth = _smooth * 0.55 + clamped * 0.45;
      _levels.removeAt(0);
      _levels.add(_smooth);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Gaya tetap gelap seperti desain (cocok di light & dark mode).
    const pill = Color(0xFF1B1B1D);
    const sendBlue = Color(0xFF2F4BFE);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: pill,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.actionsEnabled ? widget.onPickFiles : null,
            tooltip: 'Lampirkan file',
            icon: const Icon(Icons.add, size: 30, color: Colors.white),
          ),
          Expanded(
            child: SizedBox(
              height: 30,
              child: CustomPaint(
                painter: _VoiceWavePainter(
                  levels: _levels,
                  phase: _phase,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Stop: lingkaran hitam + ikon kotak outline.
          Material(
            color: Colors.black,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onStop,
              child: const Tooltip(
                message: 'Selesai merekam',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.stop_rounded,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Kirim: lingkaran biru + panah atas.
          Material(
            color: widget.canSend && widget.actionsEnabled
                ? sendBlue
                : sendBlue.withValues(alpha: 0.4),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.canSend && widget.actionsEnabled
                  ? widget.onSend
                  : null,
              child: const Tooltip(
                message: 'Kirim',
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(
                    Icons.arrow_upward,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gelombang titik-garis: diam = deretan titik kecil, ada suara = batang
/// bergelombang. Di-repaint tiap tick [_phase] tanpa setState.
class _VoiceWavePainter extends CustomPainter {
  final List<double> levels;
  final Animation<double> phase;
  final Color color;

  _VoiceWavePainter({
    required this.levels,
    required this.phase,
    required this.color,
  }) : super(repaint: phase);

  @override
  void paint(Canvas canvas, Size size) {
    final n = levels.length;
    if (n == 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stepX = size.width / n;
    final t = phase.value * 2 * math.pi;
    for (var i = 0; i < n; i++) {
      // Goyangan halus agar deretan titik tetap hidup saat hening.
      final wobble =
          1.2 * math.sin(t * 2 + i * 0.65) * (0.35 + 0.65 * levels[i]);
      final h =
          (4.0 + levels[i] * (size.height - 6) + wobble).clamp(3.0, size.height);
      final cx = stepX * (i + 0.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, size.height / 2),
            width: 3.5,
            height: h,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWavePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.levels != levels;
}
