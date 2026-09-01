import 'package:flutter/material.dart';
import 'package:material3_expressive_loading_indicator/material3_expressive_loading_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// M3 Progress Indicator – proses simpan/update ke database
/// https://m3.material.io/components/progress-indicators/overview
/// https://github.com/material-components/material-components-android/blob/master/docs/components/ProgressIndicator.md
///
/// Linear wavy default: trackThickness 4dp, trackCornerRadius 50%, gap 4dp.
/// - value == null -> indeterminate wavy (ExpressiveLinearProgressIndicator)
/// - value 0..1   -> determinate linear dengan animasi 700ms
class ProgressIndicator extends StatelessWidget {
  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final double linearHeight;
  final String? semanticsLabel;

  const ProgressIndicator.linear({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.linearHeight = 4,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? kPrimary;

    if (value != null) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value!.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
        builder: (context, animatedValue, _) {
          return SizedBox(
            height: linearHeight,
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

    return SizedBox(
      height: linearHeight,
      child: ExpressiveLinearProgressIndicator(
        color: effectiveColor,
        backgroundColor: backgroundColor ?? scheme.surfaceContainerHighest,
        semanticsLabel: semanticsLabel ?? 'Saving',
      ),
    );
  }
}
