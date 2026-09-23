import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/ai_chat/models/ai_attachment.dart';

/// Pilih lampiran untuk fitur AI (maks [AiAttachment.maxCount] file @20MB).
///
/// Satu implementasi untuk AI Chat dan AI Form Agent agar validasi +
/// peringatan selalu sama: ukuran, HEIC/HEIF, .doc/.xls lama, dan file >8MB.
/// Mengembalikan lampiran BARU yang lolos validasi — pemanggil yang
/// menggabungkannya dengan daftar lampiran yang sudah ada.
Future<List<AiAttachment>> pickAiAttachments(
  BuildContext context, {
  required int existingCount,
}) async {
  if (existingCount >= AiAttachment.maxCount) {
    showAuthToast(
      context,
      'Maksimal ${AiAttachment.maxCount} file',
      isError: true,
    );
    return const [];
  }
  try {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: AiAttachment.allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return const [];
    if (!context.mounted) return const [];
    final newItems = <AiAttachment>[];
    var warnedHeic = false;
    var warnedLegacy = false;
    var warnedBig = false;
    void warnOnce(String msg) {
      if (!context.mounted) return;
      showAuthToast(context, msg, isError: true);
    }

    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      if (bytes.length > AiAttachment.maxBytesPerFile) {
        warnOnce('${f.name} melebihi 20MB');
        continue;
      }
      final ext = f.name.split('.').last.toLowerCase();
      // HEIC/HEIF tidak didukung Gemini inlineData → gagal 400 + loading
      // lama. Peringatkan dini agar user konversi ke JPG/PNG dulu.
      if ((ext == 'heic' || ext == 'heif') && !warnedHeic) {
        warnedHeic = true;
        warnOnce(
          'Foto HEIC sering gagal dibaca AI. Ubah ke JPG/PNG dulu agar cepat.',
        );
      }
      // .doc/.xls lama tidak diekstrak (lihat GeminiService) → AI buta isi.
      if ((ext == 'doc' || ext == 'xls') && !warnedLegacy) {
        warnedLegacy = true;
        warnOnce(
          'Format .doc/.xls tidak bisa dibaca AI. Simpan sebagai .docx/.xlsx/.pdf.',
        );
      }
      // File >8MB sebagai base64 membuat request belasan MB → mudah
      // timeout di koneksi HP. Tetap diizinkan, tapi peringatkan.
      if (bytes.length > 8 * 1024 * 1024 && !warnedBig) {
        warnedBig = true;
        warnOnce(
          'File besar (>8MB) membuat AI lambat & bisa gagal. Kecilkan dulu bila bisa.',
        );
      }
      newItems.add(AiAttachment(
        id: DateTime.now().microsecondsSinceEpoch.toString() + f.name,
        name: f.name,
        mime: AiAttachment.mimeFromExtension(ext),
        sizeBytes: bytes.length,
        bytes: bytes,
      ));
      if (existingCount + newItems.length >= AiAttachment.maxCount) break;
    }

    if (existingCount + newItems.length > AiAttachment.maxCount) {
      showAuthToast(
        context,
        'Maksimal ${AiAttachment.maxCount} file',
        isError: true,
      );
      newItems.removeRange(
        AiAttachment.maxCount - existingCount,
        newItems.length,
      );
    }
    return newItems;
  } catch (e) {
    if (context.mounted) {
      showAuthToast(context, 'Gagal memilih file: $e', isError: true);
    }
    return const [];
  }
}
