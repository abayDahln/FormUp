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
  final bool _isLinear;
  final bool _isContained;
  final String? semanticsLabel;

  const AppLoadingIndicator({
    super.key,
    this.size = 64,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.semanticsLabel,
  })  : _isLinear = false,
        _isContained = false;

  /// M3 Circular medium (64dp) – untuk full-screen / page loading (screen)
  /// Spec Android: indicator 38dp dalam 48dp → skala medium 64dp (active ~50dp)
  const AppLoadingIndicator.circular({
    super.key,
    this.size = 64,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
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
        return ExpressiveLinearProgressIndicator(
          value: value,
          color: effectiveColor,
          backgroundColor: backgroundColor ?? scheme.surfaceContainerHighest,
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
          semanticsLabel: semanticsLabel,
        );
      }
      // Indeterminate wavy
      return ExpressiveLinearProgressIndicator(
        color: effectiveColor,
        backgroundColor: backgroundColor ?? scheme.surfaceContainerHighest,
        minHeight: 4,
        borderRadius: BorderRadius.circular(2),
        semanticsLabel: semanticsLabel ?? 'Loading',
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
    final constraints = BoxConstraints.tightFor(
      width: size ?? 64,
      height: size ?? 64,
    );

    final morph = ExpressiveLoadingIndicator(
      color: effectiveColor,
      constraints: constraints,
      semanticsLabel: semanticsLabel ?? 'Loading',
    );

    if (_isContained) {
      // Contained: container = size, indicator = size * 38/48 (Android spec)
      final containerColor = backgroundColor ?? scheme.surfaceContainerHighest;
      final outer = size ?? 80;
      final inner = (outer * 38 / 48).clamp(18.0, 80.0).toDouble();
      return Container(
        width: outer,
        height: outer,
        decoration: BoxDecoration(
          color: containerColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: ExpressiveLoadingIndicator(
          color: effectiveColor,
          constraints: BoxConstraints.tightFor(width: inner, height: inner),
          semanticsLabel: semanticsLabel ?? 'Loading',
        ),
      );
    }

    return morph;
  }
}

/// M3 full-screen loading – Center + morphing circular (uncontained default)
class AppLoadingOverlay extends StatelessWidget {
  final String? message;
  final bool contained;
  const AppLoadingOverlay({super.key, this.message, this.contained = false});

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}