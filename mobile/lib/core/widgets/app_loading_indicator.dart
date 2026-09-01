import 'package:flutter/material.dart';
import 'package:material3_expressive_loading_indicator/material3_expressive_loading_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// M3 Loading Indicator – https://m3.material.io/components/loading-indicator/overview
/// Android spec: https://github.com/material-components/material-components-android/blob/master/docs/components/LoadingIndicator.md
///
/// Menggunakan `material3_expressive_loading_indicator` (port Android LoadingIndicator)
/// yang morph shape via RoundedPolygon + spring (softBurst, cookie, pentagon, pill, sunny...).
///  - Uncontained: indicator 38dp morphing tanpa container (default)
///  - Contained: 48dp container bulat dengan indicator 38dp di tengah (M3 Expressive)
///
/// Semua varian otomatis pakai warna Theme `kPrimary` kecuali di-override.
class AppLoadingIndicator extends StatelessWidget {
  final double? size;
  final double? strokeWidth;
  final double? value; // null = indeterminate morphing; 0..1 = determinate wavy (linear saja)
  final Color? color;
  final Color? backgroundColor;
  final double? linearHeight;
  final bool _isLinear;
  final bool _isContained;
  final String? semanticsLabel;

  const AppLoadingIndicator({
    super.key,
    this.size = 72,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.linearHeight,
    this.semanticsLabel,
  })  : _isLinear = false,
        _isContained = false;

  /// M3 Circular medium (72dp) – untuk full-screen / page loading (screen)
  /// Spec Android: indicator 38dp dalam 48dp → medium 72dp (active ~57dp, sedang)
  const AppLoadingIndicator.circular({
    super.key,
    this.size = 72,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.linearHeight,
    this.semanticsLabel,
  })  : _isLinear = false,
        _isContained = false;

  /// M3 Contained – 80dp container bulat dengan indicator ~63dp di tengah (medium)
  /// https://github.com/material-components/material-components-android/blob/master/docs/components/LoadingIndicator.md#code-implementation (contained)
  /// Cocok untuk page loading yang butuh background – medium 80dp.
  const AppLoadingIndicator.contained({
    super.key,
    this.size = 80,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.linearHeight,
    this.semanticsLabel,
  })  : _isLinear = false,
        _isContained = true;

  /// M3 Circular inline (36dp) – untuk card, list bottom, image placeholder
  const AppLoadingIndicator.inline({
    super.key,
    this.size = 36,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.linearHeight,
    this.semanticsLabel,
  })  : _isLinear = false,
        _isContained = false;

  /// M3 Circular kecil (24dp) – KHUSUS untuk swipe refresh (RefreshIndicator)
  const AppLoadingIndicator.small({
    super.key,
    this.size = 24,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.linearHeight,
    this.semanticsLabel,
  })  : _isLinear = false,
        _isContained = false;

  /// M3 Circular untuk di dalam tombol – putih, 18dp
  const AppLoadingIndicator.button({
    super.key,
    this.size = 18,
    this.strokeWidth,
    this.value,
    this.color = Colors.white,
    this.backgroundColor,
    this.linearHeight,
    this.semanticsLabel,
  })  : _isLinear = false,
        _isContained = false;

  /// M3 Linear wavy – determinate/indeterminate bergelombang (M3 Expressive)
  /// Spec: track height 4dp, wavelength 24, gap 4dp, rounded stop.
  const AppLoadingIndicator.linear({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.linearHeight = 2,
    this.semanticsLabel,
  })  : _isLinear = true,
        _isContained = false,
        size = null,
        strokeWidth = null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? kPrimary;

    if (_isLinear) {
      // Determinate wavy linear (Expressive) – phase scroll otomatis
      if (value != null) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value!.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
          builder: (context, animatedValue, _) {
            return SizedBox(
              height: linearHeight ?? 2,
              child: LinearProgressIndicator(
                value: animatedValue,
                color: effectiveColor,
                backgroundColor: backgroundColor ?? scheme.surfaceContainerHighest,
                semanticsLabel: semanticsLabel,
              ),
            );
          },
        );
      }
      // Indeterminate wavy
      return SizedBox(
        height: linearHeight ?? 2,
        child: ExpressiveLinearProgressIndicator(
          color: effectiveColor,
          backgroundColor: backgroundColor ?? scheme.surfaceContainerHighest,
          semanticsLabel: semanticsLabel ?? 'Loading',
        ),
      );
    }

    // Determinate circular fallback pakai CircularProgressIndicator lama
    // karena ExpressiveLoadingIndicator hanya indeterminate (morphing).
    if (value != null) {
      final indicator = CircularProgressIndicator(
        value: value,
        color: effectiveColor,
        backgroundColor: backgroundColor,
        strokeWidth: strokeWidth ?? 4,
        strokeCap: StrokeCap.round,
        semanticsLabel: semanticsLabel ?? 'Loading',
      );
      if (size == null) return indicator;
      return SizedBox(width: size, height: size, child: indicator);
    }

    // Indeterminate morphing – Android LoadingIndicator (contained vs uncontained)
    // ROOT CAUSE: ExpressiveLoadingIndicator internal scale = activeSize(38)/minSide,
    // jadi shape selalu ~38dp apapun constraints. Fix: untuk ukuran medium/large
    // (>=48) render base 48dp lalu scale via Transform.scale agar `size`
    // benar-benar membesar. Untuk ukuran kecil (<=36) pakai constraints
    // langsung agar tidak jadi kecil di dalam circle swipe-refresh.
    const base = 48.0;
    final targetSize = size ?? 72;

    // Ukuran kecil (swipe refresh 24, inline 36, button 18) jangan di-scale
    // via base 48 – pakai package langsung agar proporsi tetap pas.
    if (targetSize <= 36) {
      return ExpressiveLoadingIndicator(
        color: effectiveColor,
        constraints: BoxConstraints.tightFor(width: targetSize, height: targetSize),
        semanticsLabel: semanticsLabel ?? 'Loading',
      );
    }

    Widget buildScaled(double outerSize) {
      final scale = outerSize / base;
      return SizedBox(
        width: outerSize,
        height: outerSize,
        child: Center(
          child: Transform.scale(
            scale: scale,
            child: ExpressiveLoadingIndicator(
              color: effectiveColor,
              constraints: const BoxConstraints.tightFor(width: base, height: base),
              semanticsLabel: semanticsLabel ?? 'Loading',
            ),
          ),
        ),
      );
    }

    if (_isContained) {
      final containerColor = backgroundColor ?? scheme.surfaceContainerHighest;
      final outer = targetSize;
      final inner = (outer * 38 / 48).clamp(18.0, 80.0).toDouble();
      // Container tetap outer, indicator diskalakan ke inner
      return Container(
        width: outer,
        height: outer,
        decoration: BoxDecoration(
          color: containerColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: SizedBox(
          width: inner,
          height: inner,
          child: Center(
            child: Transform.scale(
              scale: inner / base,
              child: ExpressiveLoadingIndicator(
                color: effectiveColor,
                constraints: const BoxConstraints.tightFor(width: base, height: base),
                semanticsLabel: semanticsLabel ?? 'Loading',
              ),
            ),
          ),
        ),
      );
    }

    return buildScaled(targetSize);
  }
}

/// M3 full-screen loading – true vertical center (akun AppBar)
/// Sebelumnya `Center` di `Scaffold.body` berada sedikit di atas karena
/// body berada di bawah AppBar. Tambah offset 24dp agar tampak di tengah
/// visual screen/container.
class AppLoadingOverlay extends StatelessWidget {
  final String? message;
  final bool contained;
  const AppLoadingOverlay({super.key, this.message, this.contained = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (contained) const AppLoadingIndicator.contained() else const AppLoadingIndicator.circular(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
