import 'package:flutter/material.dart';

/// Shimmer halus tanpa dependensi tambahan — kilau putih berjalan di atas
/// placeholder abu agar loading terlihat hidup, bukan spinner/full-blank.
class _Shimmer extends StatefulWidget {
  final Widget child;

  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)
      ..repeat(
        min: -1.0,
        max: 2.0,
        period: const Duration(milliseconds: 1500),
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _stop(double v) => v.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final t = _controller.value;
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.55),
              Colors.transparent,
            ],
            stops: [_stop(t - 0.25), _stop(t), _stop(t + 0.25)],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Satu balok placeholder abu (otomatis ikut tema terang/gelap).
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Lingkaran placeholder (avatar/icon).
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton satu baris aktivitas (avatar + 2 baris teks).
class SkeletonListTile extends StatelessWidget {
  final bool showAvatar;

  const SkeletonListTile({super.key, this.showAvatar = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAvatar) ...[
            const SkeletonCircle(size: 34),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 180),
                SizedBox(height: 8),
                SkeletonBox(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton kartu form (judul + subjudul + footer).
class SkeletonFormCard extends StatelessWidget {
  const SkeletonFormCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 200),
          SizedBox(height: 8),
          SkeletonBox(width: 140, height: 12),
          SizedBox(height: 14),
          Row(
            children: [
              SkeletonBox(width: 64, height: 22, borderRadius: 11),
              SizedBox(width: 8),
              SkeletonBox(width: 64, height: 22, borderRadius: 11),
              Spacer(),
              SkeletonBox(width: 24, height: 24, borderRadius: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// Daftar skeleton dengan SATU sapuan kilau (lebih murah & selaras).
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final Widget Function(int index) itemBuilder;
  final double gap;

  const SkeletonList({
    super.key,
    this.itemCount = 3,
    required this.itemBuilder,
    this.gap = 12,
  });

  /// Varian baris aktivitas.
  const SkeletonList.tiles({super.key, this.itemCount = 3, this.gap = 0})
      : itemBuilder = _tileBuilder;

  /// Varian kartu form.
  const SkeletonList.cards({super.key, this.itemCount = 3, this.gap = 12})
      : itemBuilder = _cardBuilder;

  static Widget _tileBuilder(int _) => const SkeletonListTile();
  static Widget _cardBuilder(int _) => const SkeletonFormCard();

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            if (i > 0) SizedBox(height: gap),
            itemBuilder(i),
          ],
        ],
      ),
    );
  }
}
