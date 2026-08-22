import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Dialog konfirmasi keluar: simpan / buang draf / batal.
/// Mengembalikan 'cancel' | 'discard' | 'save'.
Future<String?> showExitConfirmDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(
        'Simpan Perubahan?',
        style: TextStyle(fontFamily: kFontBold),
      ),
      content: const Text(
        'Perubahan soal belum disimpan. Simpan atau buang draf?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'cancel'),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'discard'),
          child: const Text(
            'Buang Draf',
            style: TextStyle(color: Color(0xFFC0392B)),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'save'),
          child: const Text(
            'Simpan',
            style: TextStyle(color: kAuthPrimary),
          ),
        ),
      ],
    ),
  );
}

/// Dialog konfirmasi simpan soal.
Future<bool?> showSaveConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(
        'Simpan Soal?',
        style: TextStyle(fontFamily: kFontBold),
      ),
      content: const Text(
        'Semua perubahan soal akan disimpan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Simpan',
            style: TextStyle(color: kAuthPrimary),
          ),
        ),
      ],
    ),
  );
}

/// Dialog konfirmasi simpan pada layar edit soal.
Future<bool?> showQuestionEditSaveDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(
        'Simpan Soal?',
        style: TextStyle(fontFamily: kFontBold),
      ),
      content: const Text('Soal akan disimpan ke draf kelola soal.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Simpan',
            style: TextStyle(color: kAuthPrimary),
          ),
        ),
      ],
    ),
  );
}
