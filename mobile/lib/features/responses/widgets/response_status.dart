import 'dart:ui';

/// Opsi status respons
const responseStatusOptions = <(int, String)>[
  (1, 'New'),
  (2, 'Reviewed'),
  (3, 'Accepted'),
  (4, 'Rejected'),
];

int responseStatusIdOf(String? status) {
  switch (status?.toLowerCase()) {
    case 'reviewed':
      return 2;
    case 'accepted':
      return 3;
    case 'rejected':
      return 4;
    default:
      return 1;
  }
}

(String, Color, Color) responseStatusStyle(String status) {
  switch (status.toLowerCase()) {
    case 'reviewed':
      return ('Reviewed', const Color(0xFFB26A00), const Color(0xFFFFF3DE));
    case 'accepted':
      return ('Accepted', const Color(0xFF2E7D32), const Color(0xFFE3F4E8));
    case 'rejected':
      return ('Rejected', const Color(0xFFC0392B), const Color(0xFFFDE8E6));
    default:
      return ('New', const Color(0xFF2E7D32), const Color(0xFFE3F4E8));
  }
}
