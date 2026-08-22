import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Bottom sheet pemilihan sumber gambar soal (galeri / kamera)
Future<ImageSource?> showQuestionImageSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFBDC9C8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          _ImageSourceTile(
            icon: Icons.photo_library_outlined,
            label: 'Pilih dari Galeri',
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          _ImageSourceTile(
            icon: Icons.photo_camera_outlined,
            label: 'Ambil Foto',
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
}

/// Tile satu opsi sumber gambar
class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: kPrimarySoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBDC9C8)),
        ),
        child: Row(
          children: [
            Icon(icon, color: kAuthPrimary, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
