import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';

/// Panel Bagikan Form
bool _shareSheetOpen = false;

bool get shareSheetBusy => _shareSheetOpen;

Future<void> showFormShareSheet(BuildContext context, FormData form) async {
  if (_shareSheetOpen) return;
  _shareSheetOpen = true;
  final origin = apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  var link = '$origin/f/${form.formLink}';

  Uint8List? qr;
  try {
    final info = await FormService.getShareInfo(form.id);
    final shareUrl = info['shareUrl'] as String? ?? '';
    // ponytail: URL backend lengkap
    if (shareUrl.startsWith('http')) link = shareUrl;
  } catch (_) {
    // ponytail: fallback ke URL API
  }
  try {
    qr = await FormService.getShareQr(form.id);
  } catch (_) {
    qr = null; // ponytail: QR gagal, link tetap jalan
  }
  final qrBytes = qr;
  if (!context.mounted) {
    _shareSheetOpen = false;
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      return SafeArea(
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
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bagikan Form',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih cara berbagi ke responden.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      link,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, size: 18, color: cs.primary),
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
            if (qrBytes != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Image.memory(
                    qrBytes,
                    width: 160,
                    height: 160,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Container(
                      width: 160,
                      height: 160,
                      color: cs.surfaceContainerHighest,
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
                icon: Icon(
                  Icons.image_outlined,
                  size: 18,
                  color: cs.primary,
                ),
                label: Text(
                  'Bagikan QR sebagai gambar',
                  style: TextStyle(color: cs.primary, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
            ],
            AuthPrimaryButton(
              label: 'Bagikan ke aplikasi lain',
              onPressed: () => _shareText(sheetContext, form, link),
            ),
          ],
        ),
      ),
      );
    },
  ).whenComplete(() => _shareSheetOpen = false);
}

bool _shareInvoking = false;

Future<void> _shareText(BuildContext context, FormData form, String link) async {
  if (_shareInvoking) return;
  _shareInvoking = true;
  try {
    final title = richToPlainText(form.title);
    await SharePlus.instance.share(ShareParams(
      text: 'Kerjakan form "$title" di FormUp:\n$link',
      subject: title,
    ));
  } finally {
    _shareInvoking = false;
  }
}

Future<void> _shareQrFile(
  BuildContext context,
  FormData form,
  Uint8List qr,
  String link,
) async {
  if (_shareInvoking) return;
  _shareInvoking = true;
  try {
    final file = File('${Directory.systemTemp.path}/form_${form.formLink}.png');
    await file.writeAsBytes(qr);
    final title = richToPlainText(form.title);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: 'Kerjakan form "$title" di FormUp:\n$link',
    ));
  } finally {
    _shareInvoking = false;
  }
}

