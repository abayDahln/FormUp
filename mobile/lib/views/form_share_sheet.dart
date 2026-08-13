import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'auth_widgets.dart';
import 'rich_editor.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';

/// Panel "Bagikan Form" — 3 opsi: salin link, bagikan QR, bagikan via aplikasi
/// terpasang (WhatsApp, Instagram, TikTok, dll). Dipakai dari menu kartu form
/// dan halaman detail.
Future<void> showFormShareSheet(BuildContext context, FormData form) async {
  final origin = apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  var link = '$origin/f/${form.formLink}';

  Uint8List? qr;
  try {
    final info = await FormService.getShareInfo(form.id);
    link = info['shareUrl'] as String? ?? link;
  } catch (_) {
    // ponytail: gagal ambil shareUrl backend — fallback ke URL dari API.
  }
  try {
    qr = await FormService.getShareQr(form.id);
  } catch (_) {
    qr = null; // ponytail: QR gagal dimuat bukan halangan — link tetap bisa dibagikan.
  }
  final qrBytes = qr;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bagikan Form',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pilih cara berbagi ke responden.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            // Opsi 1: salin link
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 18, color: kAuthText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      link,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: kAuthPrimary),
                    tooltip: 'Salin link',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      showAuthToast(sheetContext, 'Link form disalin');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Opsi 2: bagikan QR
            if (qrBytes != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBDC9C8)),
                  ),
                  child: Image.memory(
                    qrBytes,
                    width: 160,
                    height: 160,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Container(
                      width: 160,
                      height: 160,
                      color: const Color(0xFFF0F4F4),
                      child: const Icon(
                        Icons.qr_code_2,
                        color: Colors.grey,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _shareQrFile(sheetContext, form, qrBytes, link),
                icon: const Icon(
                  Icons.image_outlined,
                  size: 18,
                  color: kAuthPrimary,
                ),
                label: const Text(
                  'Bagikan QR sebagai gambar',
                  style: TextStyle(color: kAuthPrimary, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Opsi 3: bagikan via aplikasi terpasang
            AuthPrimaryButton(
              label: 'Bagikan ke aplikasi lain',
              onPressed: () => _shareText(sheetContext, form, link),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _shareText(BuildContext context, FormData form, String link) async {
  final title = richToPlainText(form.title);
  await SharePlus.instance.share(ShareParams(
    text: 'Kerjakan form "$title" di FormUp:\n$link',
    subject: title,
  ));
}

Future<void> _shareQrFile(
  BuildContext context,
  FormData form,
  Uint8List qr,
  String link,
) async {
  final file = File('${Directory.systemTemp.path}/form_${form.formLink}.png');
  await file.writeAsBytes(qr);
  final title = richToPlainText(form.title);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path)],
    text: 'Kerjakan form "$title" di FormUp:\n$link',
  ));
}
