import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Avatar profil dengan tombol kamera untuk memilih gambar
class ProfileAvatar extends StatelessWidget {
  final String? currentImagePath;
  final Uint8List? newImage;
  final String name;
  final VoidCallback onPick;

  const ProfileAvatar({
    super.key,
    required this.currentImagePath,
    required this.newImage,
    required this.name,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(50),
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: Color(0xFFB8E2DE),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: _avatarContent(),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF2A9D8F),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarContent() {
    if (newImage != null) {
      return Image.memory(
        newImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _avatarFallback(),
      );
    }
    final path = currentImagePath;
    if (path != null && path.isNotEmpty) {
      return Image.network(
        profileImageUrl(path),
        fit: BoxFit.cover,
        cacheWidth: 300,
        errorBuilder: (_, _, _) => _avatarFallback(),
      );
    }
    return _avatarFallback();
  }

  Widget _avatarFallback() {
    final trimmed = name.trim();
    return Center(
      child: Text(
        trimmed.isEmpty ? 'U' : trimmed[0].toUpperCase(),
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          color: kAuthPrimary,
        ),
      ),
    );
  }
}
