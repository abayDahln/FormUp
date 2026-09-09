import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/widgets/full_screen_image_viewer.dart';
import 'package:form_up/features/form/controllers/form_maker_controller.dart';
import 'package:form_up/features/form/widgets/form_maker_settings_card.dart';

/// Kartu header + pengaturan form maker: judul, deskripsi, banner, dan semua
/// setting dalam satu card. Banner: tap 1x = ganti gambar, tahan ≥250ms = lihat penuh.
class FormMakerHeaderCard extends StatelessWidget {
  final TextEditingController titleController;
  final QuillController descController;
  final String? bannerImage;
  final Uint8List? newBanner;
  final VoidCallback onPickBanner;
  final FocusNode? titleFocusNode;
  final Key? titleFieldKey;
  final bool embedded;

  // Pengaturan (diteruskan ke FormMakerSettingsCard embedded)
  final FormMakerController? settingsController;
  final VoidCallback? onSettingsChanged;
  final VoidCallback? onPickOpenTime;
  final VoidCallback? onPickCloseTime;

  const FormMakerHeaderCard({
    super.key,
    required this.titleController,
    required this.descController,
    required this.bannerImage,
    required this.newBanner,
    required this.onPickBanner,
    this.titleFocusNode,
    this.titleFieldKey,
    this.embedded = false,
    this.settingsController,
    this.onSettingsChanged,
    this.onPickOpenTime,
    this.onPickCloseTime,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inner = _buildInner(context);
    if (embedded) return inner;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: inner,
    );
  }

  Widget _buildInner(BuildContext context) {
    final hasSettings = settingsController != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              "Judul Form",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 2),
            const Text(
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
          style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
          cursorColor: Theme.of(context).colorScheme.primary,
          decoration: formUpInputDecoration(
            hintText: "Judul form Anda",
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Deskripsi",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        RichTextEditor(
          controller: descController,
          hint: "Jelaskan tujuan form Anda",
          minHeight: 60,
        ),
        const SizedBox(height: 16),
        _buildBannerField(context),
        if (hasSettings) ...[
          const SizedBox(height: 20),
          Divider(color: Theme.of(context).colorScheme.outlineVariant, thickness: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.tune, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                "Pengaturan",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FormMakerSettingsCard(
            controller: settingsController!,
            onChanged: onSettingsChanged!,
            onPickOpenTime: onPickOpenTime!,
            onPickCloseTime: onPickCloseTime!,
            embedded: true,
          ),
        ],
      ],
    );
  }

  Widget _buildBannerField(BuildContext context) {
    final hasImage = newBanner != null || (bannerImage?.isNotEmpty ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Banner Form",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        _BannerTapArea(
          hasImage: hasImage,
          newBanner: newBanner,
          bannerImage: bannerImage,
          onPickBanner: onPickBanner,
        ),
      ],
    );
  }
}

/// Area banner: tap 1x = add/edit, long-press ≥250ms = full preview
class _BannerTapArea extends StatefulWidget {
  final bool hasImage;
  final Uint8List? newBanner;
  final String? bannerImage;
  final VoidCallback onPickBanner;

  const _BannerTapArea({
    required this.hasImage,
    required this.newBanner,
    required this.bannerImage,
    required this.onPickBanner,
  });

  @override
  State<_BannerTapArea> createState() => _BannerTapAreaState();
}

class _BannerTapAreaState extends State<_BannerTapArea> {
  Timer? _timer;
  bool _isLong = false;

  void _showFull(BuildContext context) {
    if (!widget.hasImage) return;
    if (widget.newBanner != null) {
      showDialog(
        context: context,
        barrierColor: Theme.of(context).colorScheme.onSurface,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(widget.newBanner!, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (widget.bannerImage != null && widget.bannerImage!.isNotEmpty) {
      showFullScreenImage(context, profileImageUrl(widget.bannerImage));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) {
        _isLong = false;
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 250), () {
          _isLong = true;
          if (widget.hasImage) _showFull(context);
        });
      },
      onTapUp: (_) {
        _timer?.cancel();
        if (!_isLong) widget.onPickBanner();
        Future.delayed(const Duration(milliseconds: 100), () => _isLong = false);
      },
      onTapCancel: () {
        _timer?.cancel();
        _isLong = false;
      },
      child: Container(
        height: 140,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        child: widget.hasImage
            ? (widget.newBanner != null
                ? Image.memory(
                    widget.newBanner!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(Icons.broken_image_outlined, size: 32, color: cs.onSurfaceVariant),
                    ),
                  )
                : CachedRemoteImage(
                    url: profileImageUrl(widget.bannerImage),
                    fit: BoxFit.cover,
                    errorWidget: Center(
                      child: Icon(Icons.broken_image_outlined, size: 32, color: cs.onSurfaceVariant),
                    ),
                  ))
            : Center(
                child: Icon(Icons.image_outlined, size: 32, color: cs.onSurfaceVariant),
              ),
      ),
    );
  }
}


