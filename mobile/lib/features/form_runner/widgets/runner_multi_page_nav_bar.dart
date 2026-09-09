import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Bar navigasi mode multi-page: Sebelumnya / Berikutnya (atau Kirim)
class RunnerMultiPageNavBar extends StatelessWidget {
  final bool canGoBack;
  final bool isLast;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onNextOrSubmit;

  const RunnerMultiPageNavBar({
    super.key,
    required this.canGoBack,
    required this.isLast,
    required this.submitting,
    required this.onBack,
    required this.onNextOrSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        color: cs.surface,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: canGoBack ? onBack : null,
                style: OutlinedButton.styleFrom(
                  side:  BorderSide(color: cs.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child:  Text(
                  "Sebelumnya",
                  style: TextStyle(color: cs.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AuthPrimaryButton(
                label: isLast
                    ? (submitting ? "Mengirim..." : "Kirim Jawaban")
                    : "Berikutnya",
                showArrow: false,
                loading: submitting,
                onPressed: onNextOrSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
