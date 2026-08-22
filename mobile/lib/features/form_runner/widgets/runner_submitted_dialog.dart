import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Dialog konfirmasi jawaban sudah terkirim.
/// Mengembalikan 'back' atau 'result' (bila user login).
Future<String?> showRunnerSubmittedDialog(
  BuildContext context, {
  String message = 'Jawaban Anda sudah terkirim.',
  required bool viewResponse,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        'Jawaban Terkirim',
        style: TextStyle(fontFamily: kFontBold),
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'back'),
          child: Text(
            viewResponse ? 'Kembali ke Beranda' : 'Kembali',
          ),
        ),
        if (viewResponse)
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'result'),
            child: const Text(
              'Lihat Respons',
              style: TextStyle(color: kAuthPrimary),
            ),
          ),
      ],
    ),
  );
}
