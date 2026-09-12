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
          child: Text(
            'Simpan',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    ),
  );
}

/// B5: dialog draf yatim — penyimpanan bertahap gagal di tengah sehingga
/// form kosong tertinggal di server. Mengembalikan 'delete' | 'keep' | null.
Future<String?> showOrphanFormDialog(BuildContext context, Object error) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text(
        'Penyimpanan Belum Selesai',
        style: TextStyle(fontFamily: kFontBold),
      ),
      content: Text(
        'Form dibuat tetapi langkah lanjutan gagal ($error). '
        'Hapus draf kosong ini atau biarkan untuk dilanjutkan nanti?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'keep'),
          child: const Text('Lanjutkan Nanti'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'delete'),
          child: const Text(
            'Hapus Draf',
            style: TextStyle(color: Color(0xFFC0392B)),
          ),
        ),
      ],
    ),
  );
}
