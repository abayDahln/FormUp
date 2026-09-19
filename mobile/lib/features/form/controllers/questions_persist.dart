import 'dart:typed_data';

import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/features/form/controllers/question_payload_builder.dart';

/// Hasil persist soal murni (tanpa UI).
class PersistQuestionsResult {
  /// True bila daftar kosong → semua soal dihapus via deleteAllQuestions.
  final bool deletedAll;

  /// Jumlah media yang gagal diupload (soal tetap tersimpan).
  final int mediaFailed;

  /// True bila berhenti dini karena media soal >10MB (belum selesai).
  final bool abortedOversize;

  const PersistQuestionsResult({
    required this.deletedAll,
    this.mediaFailed = 0,
    this.abortedOversize = false,
  });
}

/// Simpan daftar soal + medianya ke server — logika yang sebelumnya inline
/// di QuestionsPanel._save, dipakai ulang layar builder. Tanpa UI kecuali
/// [notify] untuk peringatan non-fatal. Progress 0.1..1.0 via [onProgress].
/// Melempar saat gagal fatal (caller toast + tangani).
Future<PersistQuestionsResult> persistQuestions({
  required int formId,
  required List<QuestionDraft> questions,
  void Function(double)? onProgress,
  void Function(String message, {bool isError})? notify,
}) async {
  onProgress?.call(0.1);
  if (questions.isEmpty) {
    await FormService.deleteAllQuestions(formId);
    onProgress?.call(1.0);
    return const PersistQuestionsResult(deletedAll: true);
  }

  final payload = buildQuestionsPayload(questions);
  final saved = await FormService.updateQuestions(formId, payload);
  onProgress?.call(0.7);

  // Queue upload media draf: soal baru belum punya id, jadi upload
  // setelah server balikkan id. Server kembalikan daftar berurutan sesuai questionOrder.
  for (var i = 0; i < questions.length && i < saved.length; i++) {
    questions[i].id ??= saved[i]['id'] as int?;
  }
  final uploads = <(QuestionDraft, Uint8List, String, bool)>[];
  for (final q in questions) {
    if (q.pendingImageBytes == null && q.pendingAudioBytes == null) {
      continue;
    }
    if (q.id == null) continue;
    if (q.pendingImageBytes != null) {
      uploads.add((
        q,
        q.pendingImageBytes!,
        q.pendingImageName ?? 'question.jpg',
        true,
      ));
    }
    if (q.pendingAudioBytes != null) {
      uploads.add((
        q,
        q.pendingAudioBytes!,
        q.pendingAudioName ?? 'audio',
        false,
      ));
    }
  }

  // Validasi ukuran semua media dulu sebelum upload.
  for (final (_, bytes, _, _) in uploads) {
    if (exceedsUploadLimit(bytes)) {
      notify?.call("Media maksimal 10 MB", isError: true);
      return const PersistQuestionsResult(
          deletedAll: false, abortedOversize: true);
    }
  }

  var mediaFailed = 0;
  if (uploads.isNotEmpty) {
    onProgress?.call(0.85);
  }
  for (var i = 0; i < uploads.length; i++) {
    final (q, bytes, name, isImage) = uploads[i];
    try {
      if (isImage) {
        q.questionImage = await FormService.uploadQuestionImage(
          formId,
          q.id!,
          bytes,
          name,
        );
      } else {
        q.questionAudio = await FormService.uploadQuestionAudio(
          formId,
          q.id!,
          bytes,
          name,
        );
      }
      q.pendingImageBytes = null;
      q.pendingImageName = null;
      q.pendingAudioBytes = null;
      q.pendingAudioName = null;
    } catch (e) {
      // Pending SENGAJA tidak dibersihkan → coba lagi next Simpan.
      mediaFailed++;
      notify?.call(
        "Gagal upload media (${AuthService.errorMessage(e)})",
        isError: true,
      );
    }
    onProgress?.call(0.85 + (0.15 * (i + 1) / uploads.length));
  }

  // Upload gambar opsi draf: butuh id soal + id opsi dari hasil save
  // (server kembalikan opsi berurutan sesuai optionOrder).
  for (var i = 0; i < questions.length && i < saved.length; i++) {
    final q = questions[i];
    final savedOpts = (saved[i]['options'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    for (var j = 0; j < q.options.length && j < savedOpts.length; j++) {
      q.options[j].id ??= savedOpts[j]['id'] as int?;
    }
  }
  for (final q in questions) {
    if (q.id == null) continue;
    for (final o in q.options) {
      final bytes = o.pendingImageBytes;
      if (bytes == null || o.id == null) continue;
      if (exceedsUploadLimit(bytes)) {
        notify?.call('Gambar opsi maksimal 10 MB — 1 file dilewati',
            isError: true);
        o.pendingImageBytes = null;
        o.pendingImageName = null;
        continue;
      }
      try {
        o.optionImage = await FormService.uploadOptionImage(
          formId,
          q.id!,
          o.id!,
          bytes,
          o.pendingImageName ?? 'option.jpg',
        );
        o.pendingImageBytes = null;
        o.pendingImageName = null;
      } catch (e) {
        // Pending dipertahankan untuk coba lagi (jangan finally-clear).
        mediaFailed++;
        notify?.call(
          'Gagal upload gambar opsi (${AuthService.errorMessage(e)})',
          isError: true,
        );
      }
    }
  }
  onProgress?.call(1.0);
  return PersistQuestionsResult(
      deletedAll: false, mediaFailed: mediaFailed);
}
