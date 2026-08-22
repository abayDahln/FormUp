import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Dialog konfirmasi keluar dari form.
/// [onSubmitAndExit] dipanggil saat user memilih "Kirim dan Keluar";
/// hasilnya (berhasil/kirim) menjadi nilai balik dialog.
Future<bool> showRunnerExitDialog(
  BuildContext context,
  Future<bool> Function() onSubmitAndExit,
) async {
  final exit = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        "Keluar dari Form?",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          color: Colors.black87,
        ),
      ),
      content: const Text(
        "Apakah Anda yakin ingin keluar? Jawaban Anda akan dikumpulkan.",
        style: TextStyle(fontSize: 14, color: Colors.black54),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("Batalkan",
              style: TextStyle(color: Colors.black54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kAuthPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () async {
            final ok = await onSubmitAndExit();
            if (ctx.mounted) Navigator.pop(ctx, ok);
          },
          child: const Text("Kirim dan Keluar"),
        ),
      ],
    ),
  );
  return exit ?? false;
}
