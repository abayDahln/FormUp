import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Kartu header form maker: judul (plain text), deskripsi (rich), dan banner
class FormMakerHeaderCard extends StatelessWidget {
  final TextEditingController titleController;
  final QuillController descController;
  final String? bannerImage;
  final Uint8List? newBanner;
  final VoidCallback onPickBanner;
  final VoidCallback onRemoveBanner;
  final FocusNode? titleFocusNode;
  final Key? titleFieldKey;

  const FormMakerHeaderCard({
    super.key,
    required this.titleController,
    required this.descController,
    required this.bannerImage,
    required this.newBanner,
    required this.onPickBanner,
    required this.onRemoveBanner,
    this.titleFocusNode,
    this.titleFieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xCCBDC9C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Text(
                "Judul Form",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: kAuthPrimary,
                ),
              ),
              SizedBox(width: 2),
              Text(
                "*",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: kDangerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleController,
            focusNode: titleFocusNode,
            key: titleFieldKey,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            cursorColor: kAuthPrimary,
            decoration: formUpInputDecoration(
              hintText: "Contoh: Survey Kepuasan",
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Deskripsi",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: kAuthPrimary,
            ),
          ),
          const SizedBox(height: 8),
          RichTextEditor(
            controller: descController,
            hint: "Jelaskan tujuan form Anda",
            minHeight: 60,
          ),
          const SizedBox(height: 16),
          _buildBannerField(),
        ],
      ),
    );
  }

  Widget _buildBannerField() {
    final hasImage = newBanner != null || (bannerImage?.isNotEmpty ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Banner Form",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: kAuthPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 140,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6E7979)),
          ),
              child: hasImage
                  ? (newBanner != null
                      ? Image.memory(
                          newBanner!,
                          fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined,
                              size: 32, color: Colors.grey),
                        ),
                      )
                      : CachedRemoteImage(
                          url: profileImageUrl(bannerImage),
                          fit: BoxFit.cover,
                          errorWidget: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                size: 32, color: Colors.grey),
                          ),
                        ))
              : const Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 32,
                    color: Colors.grey,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickBanner,
                icon: const Icon(Icons.upload_outlined, size: 18, color: kAuthPrimary),
                label: Text(
                  hasImage ? "Ganti Banner" : "Upload Banner",
                  style: const TextStyle(color: kAuthPrimary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kAuthPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onRemoveBanner,
                icon: const Icon(Icons.close, size: 18, color: Color(0xFFC0392B)),
                label: const Text(
                  "Hapus",
                  style: TextStyle(color: Color(0xFFC0392B)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFC0392B)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
