import 'package:flutter/material.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// M3 Swipe Refresh – Morphing 24dp small khusus pull-to-refresh
/// https://github.com/material-components/material-components-android/blob/master/docs/components/LoadingIndicator.md
/// Menggunakan CustomRefreshIndicator + AppLoadingIndicator.small (24dp morphing)
/// agar animasi konsisten dengan M3 LoadingIndicator (bukan CircularProgressIndicator bawaan).
class AppRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? backgroundColor;
  final Color? indicatorColor;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.backgroundColor,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomMaterialIndicator(
      onRefresh: onRefresh,
      backgroundColor: backgroundColor ?? Colors.white,
      elevation: 2,
      // M3: 24dp small morphing saat refresh, pull progress tetap terlihat
      indicatorBuilder: (context, controller) {
        // controller.value 0..1 saat drag, >1 saat armed, isLoading saat refresh
        final isLoading = controller.state == IndicatorState.loading;
        final isDragging = controller.state == IndicatorState.dragging || controller.state == IndicatorState.armed;
        // scale morphing sedikit saat drag (feedback)
        final dragProgress = controller.value.clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: isLoading ? 1 : (0.7 + dragProgress * 0.3),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: softShadow(alpha: 0.08),
              ),
              alignment: Alignment.center,
              child: isLoading || isDragging
                  ? AppLoadingIndicator.small(
                      color: indicatorColor ?? kPrimary,
                    )
                  : const AppLoadingIndicator.small(color: kPrimary),
            ),
          ),
        );
      },
      child: child,
    );
  }
}