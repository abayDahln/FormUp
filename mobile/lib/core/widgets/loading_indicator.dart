import 'package:flutter/material.dart';
import 'package:material3_expressive_loading_indicator/material3_expressive_loading_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// M3 Loading Indicator – menunggu data muncul (indeterminate, tanpa value)
/// https://m3.material.io/components/loading-indicator/overview
/// https://github.com/material-components/material-components-android/blob/master/docs/components/LoadingIndicator.md
///
/// - Contained 80dp: page load (berisi container bulat)
/// - Uncontained: circular morphing tanpa container (default)
/// - Inline 36dp: placeholder media/card tanpa container
/// - Small 24dp: khusus swipe refresh
/// - Button 18dp: di dalam tombol
class LoadingIndicator extends StatelessWidget {
  final double? size;
  final double? strokeWidth;
  final double? value; // determinate fallback (jarang dipakai untuk loading)
  final Color? color;
  final Color? backgroundColor;
  final bool _isContained;
  final String? semanticsLabel;

  const LoadingIndicator({
    super.key,
    this.size = 96,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.semanticsLabel,
  }) : _isContained = false;

  /// M3 Circular medium 96dp – page loading uncontained (diperbesar agar tampak di tengah list)
  const LoadingIndicator.circular({
    super.key,
    this.size = 96,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.semanticsLabel,
  }) : _isContained = false;

  /// M3 Contained 96dp – page loading dengan container bulat (diperbesar)
  const LoadingIndicator.contained({
    super.key,
    this.size = 96,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.semanticsLabel,
  }) : _isContained = true;

  /// M3 inline 36dp – placeholder media/card tanpa container
  const LoadingIndicator.inline({
    super.key,
    this.size = 36,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.semanticsLabel,
  }) : _isContained = false;

  /// M3 small 24dp – khusus swipe refresh
  const LoadingIndicator.small({
    super.key,
    this.size = 24,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.semanticsLabel,
  }) : _isContained = false;

  /// M3 button 18dp putih
  const LoadingIndicator.button({
    super.key,
    this.size = 18,
    this.strokeWidth,
    this.value,
    this.color = Colors.white,
    this.backgroundColor,
    this.semanticsLabel,
  }) : _isContained = false;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? kPrimary;
    final scheme = Theme.of(context).colorScheme;

    // Determinate fallback
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

    const base = 48.0;
    final targetSize = size ?? 72;

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

/// M3 full-screen loading overlay – true vertical center
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool contained;
  const LoadingOverlay({super.key, this.message, this.contained = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (contained) const LoadingIndicator.contained() else const LoadingIndicator.circular(),
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
