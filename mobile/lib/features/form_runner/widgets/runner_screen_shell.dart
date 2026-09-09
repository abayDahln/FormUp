import 'package:flutter/material.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/form_runner/widgets/countdown_badge.dart';
import 'package:form_up/features/form/widgets/form_zoom_controls.dart';

/// Shell layar kerjakan form: AppBar dengan countdown timer + background.
class RunnerScreenShell extends StatelessWidget {
  final int? timerSeconds;
  final VoidCallback onTimerExpired;
  final Widget child;

  const RunnerScreenShell({
    super.key,
    required this.timerSeconds,
    required this.onTimerExpired,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape:  Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
        leading: IconButton(
          icon:  Icon(Icons.arrow_back, color: cs.onSurface),
          // Lewat popRoute agar back guard (dialog keluar form) tetap jalan.
          onPressed: () => AppRouter.of(context).popRoute(),
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Center(child: FormZoomControls()),
          ),
          if (timerSeconds != null && timerSeconds! > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: CountdownBadge(
                  key: ValueKey(timerSeconds),
                  seconds: timerSeconds!,
                  onExpired: onTimerExpired,
                ),
              ),
            ),
        ],
      ),
      body: AuthBackground(plain: true,
        child: SafeArea(child: child),
      ),
    );
  }
}
