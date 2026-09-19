import 'dart:ui';

/// Hanya dua status respons yang dipakai: "new" (draft) dan "submitted"
/// (terkirim). Kolom status bersifat read-only — pengubahan status
/// dihapus agar kuota reset tidak bisa dirusak.
String responseStatusLabel(String? status) {
  switch (status?.toLowerCase()) {
    case 'submitted':
      return 'Submitted';
    case 'new':
    default:
      return 'New';
  }
}

(String, Color, Color) responseStatusStyle(String status) {
  switch (status.toLowerCase()) {
    case 'submitted':
      return ('Submitted', const Color(0xFF00897B), const Color(0xFFE0F2F1));
    case 'new':
    default:
      return ('New', const Color(0xFF2E7D32), const Color(0xFFE3F4E8));
  }
}
