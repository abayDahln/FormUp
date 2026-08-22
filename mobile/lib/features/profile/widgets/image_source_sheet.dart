import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Bottom sheet pemilihan sumber gambar (galeri / kamera)
Future<ImageSource?> showImageSourceSheet(BuildContext context) {
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: kAuthPrimary, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      onTap: onTap,
    );
  }
}
