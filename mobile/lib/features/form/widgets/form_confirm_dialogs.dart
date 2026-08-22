import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Dialog konfirmasi keluar form maker: simpan / buang draf / batal.
/// Mengembalikan 'cancel' | 'discard' | 'save'.
Future<String?> showFormExitConfirmDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(
        'Simpan Perubahan?',
        style: TextStyle(fontFamily: kFontBold),
      ),
      content: const Text(
        'Perubahan form belum disimpan. Simpan atau buang draf?',
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
