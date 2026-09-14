import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/ai_chat/models/ai_attachment.dart';

/// Dialog preview gambar lampiran chat AI — responsif:
/// - Mobile (<600): ~92% lebar layar, tinggi maks 70% layar.
/// - Tablet (600-1023): maks lebar 560.
/// - Desktop (>=1024): maks lebar 720, tinggi maks 80% layar.
/// Zoom & pan via InteractiveViewer. Hanya warna tema yang dipakai.
void showImagePreview(BuildContext context, AiAttachment attachment) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.54),
    builder: (dialogCtx) {
      final cs = Theme.of(dialogCtx).colorScheme;
      final size = MediaQuery.sizeOf(dialogCtx);
      final maxW = size.width >= 1024
          ? 720.0
          : (size.width >= 600 ? 560.0 : size.width * 0.92);
      final maxH = size.height * (size.width >= 1024 ? 0.8 : 0.7);
      return Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: nama file + tombol tutup (dengan hover).
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Icon(Icons.image_outlined, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        attachment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: kFontBold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      tooltip: 'Tutup',
                      style: IconButton.styleFrom(
                        hoverColor: cs.onSurfaceVariant.withValues(alpha: 0.12),
                        highlightColor: cs.onSurfaceVariant.withValues(alpha: 0.20),
                      ),
                      icon: Icon(Icons.close, size: 20, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  color: cs.surfaceContainerLowest,
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Center(
                      child: Image.memory(
                        attachment.bytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}