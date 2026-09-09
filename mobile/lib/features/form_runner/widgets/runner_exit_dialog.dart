import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

enum RunnerExitAction { stay, exitWithoutSubmit }

/// Dialog konfirmasi keluar dari form.
/// Keluar = langsung keluar tanpa submit, tidak tercatat sebagai responden.
Future<RunnerExitAction> showRunnerExitDialog(BuildContext context) async {
  final action = await showDialog<RunnerExitAction>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "Keluar dari Form?",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          color: Theme.of(ctx).colorScheme.onSurface,
        ),
      ),
      content: Text(
        "Jawaban yang belum dikirim tidak akan tersimpan dan tidak tercatat sebagai pengerjaan.",
        style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, RunnerExitAction.stay),
          child: Text("Batal", style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC0392B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx, RunnerExitAction.exitWithoutSubmit),
          child: const Text("Keluar"),
        ),
      ],
    ),
  );
  return action ?? RunnerExitAction.stay;
}
