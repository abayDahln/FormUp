import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hijau terang untuk indikator kerja AFA di kartu soal.
const Color kAiHighlightGreen = Color(0xFF00E676);

/// Bingkai highlight animasi untuk kartu soal yang baru ditambah/diubah AFA.
///
/// Efek "AI loading": busur hijau terang BERPUTAR mengelilingi stroke card
/// ([SweepGradient] yang diputar via [GradientRotation]) + glow lembut.
/// Saat [active] false, child dirender polos tanpa lapisan tambahan.
///
/// Dipakai membungkus [QuestionAccordionCard] (builder desktop) dan
/// [QuestionListCard] (panel phone) — radius disamakan dengan card (16).
class AiHighlightBorder extends StatefulWidget {
  /// True = animasi putar tampil.
  final bool active;

  /// Radius sudut card yang dibungkus.
  final double borderRadius;

  final Widget child;

  const AiHighlightBorder({
    super.key,
    required this.active,
    this.borderRadius = 16,
    required this.child,
  });

  @override
  State<AiHighlightBorder> createState() => _AiHighlightBorderState();
}

class _AiHighlightBorderState extends State<AiHighlightBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant AiHighlightBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Start/stop mengikuti active; controller selalu dibuang di dispose
    // sehingga aman bila card dihapus dari daftar saat animasi jalan.
    if (widget.active && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.active && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _spin,
      builder: (_, _) => Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius + 2.5),
          gradient: SweepGradient(
            center: Alignment.center,
            // Busur hijau terang dengan ekor memudar → terlihat berputar.
            colors: const [
              Colors.transparent,
              Colors.transparent,
              kAiHighlightGreen,
              Color(0xFF69F0AE),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 0.72, 0.86, 1.0],
            transform: GradientRotation(_spin.value * 2 * math.pi),
          ),
          boxShadow: [
            BoxShadow(
              color: kAiHighlightGreen.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: widget.child,
        ),
      ),
    );
  }
}
