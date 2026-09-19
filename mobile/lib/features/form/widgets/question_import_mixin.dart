import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:form_up/core/utils/action_debouncer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:form_up/core/widgets/app_toast.dart' hide showAuthToast;
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/features/form/controllers/question_validation.dart';

/// Ekstensi file yang didukung impor soal.
const kAllowedImportExt = ['pdf', 'docx', 'xlsx', 'xls', 'csv'];

/// Alur impor soal + unduh template impor, dipakai ulang panel kelola soal
/// (phone) dan layar builder (tablet/desktop). Murni logika + sheet;
/// state daftar & busy disediakan host via accessor abstrak.
mixin QuestionImportMixin<T extends StatefulWidget> on State<T> {
  /// Daftar draf yang dimutasi (di-add hasil impor yang valid).
  List<QuestionDraft> get importQuestions;

  /// null = draf lokal (impor butuh formId server → dinonaktifkan).
  int? get importFormId;

  /// True saat menyimpan/mengimpor (guard menu).
  bool get importBusy;

  /// Set flag impor host (me-refresh UI).
  void setImportBusy(bool value);

  /// Impor soal dari file .docx/.pdf/.xlsx/.csv via endpoint backend.
  /// Gambar di dalam docx/pdf ikut terekstrak ke soal.
  /// Alur: pilih file → preview (parse & validasi) → konfirmasi → save.
  Future<void> importSoal() async {
    if (!AppDebouncer.tryAcquire('form:importSoal')) return;
    if (importFormId == null || importBusy) return;

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: kAllowedImportExt,
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || !mounted) return;
    final bytes = file.bytes;
    if (bytes == null) {
      showAuthToast(context, "Gagal membaca file", isError: true);
      return;
    }

    setImportBusy(true);
    try {
      // 1) Preview: parse & validasi saja, belum menyimpan apa pun
      final preview = await FormService.previewQuestionImport(
        importFormId!,
        bytes,
        file.name,
      );
      if (!mounted) return;

      if (preview['blocked'] == true) {
        showAppToast(
          context,
          "Form sudah memiliki respons — soal tidak dapat diubah",
          type: ToastType.warning,
          title: "Impor Ditolak",
        );
        return;
      }

      final questions = (preview['questions'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      // 2) Tampilkan preview + daftar error format sebelum benar-benar impor
      final confirmed = await _showImportPreview(questions, preview);
      if (!mounted || confirmed != true) return;

      // 3) Masukkan hasil impor ke draf lokal, belum disimpan ke database.
      // Saring dengan validasi lokal: baris lolos server tapi cacat
      // (opsi kosong/duplikat, PG <2 opsi) langsung ditolak di sini.
      final importedDrafts = <QuestionDraft>[
        for (final item in questions) _draftFromImportItem(item),
      ];
      final validDrafts = <QuestionDraft>[];
      String? firstRejectReason;
      for (final d in importedDrafts) {
        final err = validateQuestionDraft(d);
        if (err == null) {
          validDrafts.add(d);
        } else {
          d.dispose();
          firstRejectReason ??= err;
        }
      }
      final rejected = importedDrafts.length - validDrafts.length;
      if (!mounted) {
        for (final d in validDrafts) {
          d.dispose();
        }
        return;
      }
      setState(() {
        importQuestions.addAll(validDrafts);
      });
      showAppToast(
        context,
        validDrafts.isEmpty
            ? 'Tidak ada soal valid untuk dimasukkan'
            : '${validDrafts.length} soal masuk draf'
                '${rejected > 0 ? ', $rejected ditolak (${firstRejectReason ?? 'tidak valid'})' : ''}',
        type: validDrafts.isNotEmpty ? ToastType.success : ToastType.warning,
        title: 'Impor Selesai',
      );
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setImportBusy(false);
    }
  }

  /// Sheet preview daftar soal hasil parse. Return true jika user menekan impor.
  /// Error format per baris ditampilkan jelas; tombol impor dinonaktifkan
  /// bila tidak ada satu pun baris valid.
  Future<bool?> _showImportPreview(
    List<Map<String, dynamic>> questions,
    Map<String, dynamic> preview,
  ) {
    final totalRows = preview['totalRows'] as int? ?? questions.length;
    final canImport = preview['canImport'] == true && questions.isNotEmpty;
    final errors = (preview['errors'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    const maxVisibleErrors = 5;
    final errorTextColor = Color.lerp(kDangerColor, Colors.black, 0.25)!;

    return AdaptiveSheet.show<bool>(
      context: context,
      isScrollControlled: true,
      selfScrolling: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext, _) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Preview Impor (${questions.length} soal dari $totalRows baris)",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: Theme.of(sheetContext).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(sheetContext, false),
                  ),
                ],
              ),
            ),
            // Daftar error format: baris, kolom, dan alasannya terlihat jelas.
            if (errors.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kDangerColor.withValues(alpha: 0.08),
                  border: Border.all(
                    color: kDangerColor.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: kDangerColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "${errors.length} baris bermasalah dan akan dilewati",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: kFontBold,
                              color: kDangerColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final e in errors.take(maxVisibleErrors))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          "• Baris ${e['rowNumber']} (${e['field']}): ${e['message']}",
                          style: TextStyle(fontSize: 11, color: errorTextColor),
                        ),
                      ),
                    if (errors.length > maxVisibleErrors)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          "... dan ${errors.length - maxVisibleErrors} error lainnya",
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: errorTextColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (questions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Tidak ada soal valid yang terbaca dari file.\n"
                    "Perbaiki baris di atas atau unduh template import untuk format yang benar.",
                    style: TextStyle(fontSize: 12, color: errorTextColor),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: centerPad(context,
                    base: const EdgeInsets.fromLTRB(20, 12, 20, 8)),
                itemCount: questions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final q = questions[i];
                  final imageDataUri = q['image'] as String?;
                  final options = (q['options'] as List<dynamic>? ?? [])
                      .whereType<String>()
                      .toList();
                  final previewCa =
                      (q['correctAnswer'] as String?)?.trim() ?? '';
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichTextView(
                          text: q['question'] as String? ?? '',
                          prefix: "${q['order']}. ",
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: kFontBold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        // Gambar soal dari server (data URI base64)
                        if (imageDataUri != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 140),
                              child: Image.memory(
                                base64Decode(imageDataUri.split(',').last),
                                fit: BoxFit.contain,
                                alignment: Alignment.centerLeft,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ],
                        // Teks opsi jawaban hasil parse (centang = kunci terdeteksi)
                        if (options.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          for (var oi = 0; oi < options.length; oi++)
                            Builder(builder: (context) {
                              final isKey = previewCa.isNotEmpty &&
                                  _resolveImportCorrect(
                                      options[oi], oi, previewCa);
                              return Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    if (isKey)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 4),
                                        child: Icon(
                                          Icons.check_circle,
                                          size: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        "• ${options[oi]}",
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isKey
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _previewChip(
                              questionTypes[q['typeId'] as int?]?.$1 ??
                                  'Tipe ${q['typeId']}',
                            ),
                            if (q['isRequired'] == true)
                              _previewChip('Wajib', kDangerColor),
                            if (options.isNotEmpty)
                              _previewChip('${options.length} opsi'),
                            if (q['hasCorrectAnswer'] == true)
                              _previewChip('Ada kunci', kSuccessColor),
                            // Chip hanya fallback bila gambar terlalu besar
                            // untuk dikirim sebagai base64 oleh server.
                            if (q['hasImage'] == true && imageDataUri == null)
                              _previewChip('Gambar'),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black26),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kRadius),
                          ),
                        ),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: canImport
                            ? () => Navigator.pop(sheetContext, true)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAuthPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.black12,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kRadius),
                          ),
                        ),
                        icon: const Icon(Icons.download_done, size: 20),
                        label: Text(
                          questions.isEmpty
                              ? 'Tidak Ada Soal Valid'
                              : 'Impor Sekarang',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewChip(String label, [Color? color]) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          color: c,
        ),
      ),
    );
  }

  /// Samakan logika server (QuestionsController Import baris ~699-718):
  /// cocok teks persis → prefix "A. teks" → huruf A-E → angka 1-based →
  /// fallback strip prefix. Mendukung multi-kunci "A,C" / "1|3".
  bool _resolveImportCorrect(String optionText, int index, String rawCa) {
    final cleanOpt = optionText.trim();
    if (cleanOpt.isEmpty) return false;
    const stripChars = ['*', '`', '\$', '"', "'"];
    String stripEdge(String s) {
      var r = s.trim();
      bool changed = true;
      while (changed && r.isNotEmpty) {
        changed = false;
        for (final c in stripChars) {
          if (r.startsWith(c)) {
            r = r.substring(1).trim();
            changed = true;
          }
          if (r.endsWith(c)) {
            r = r.substring(0, r.length - 1).trim();
            changed = true;
          }
        }
      }
      return r;
    }

    final parts = rawCa
        .split(RegExp(r'[,|]'))
        .map(stripEdge)
        .where((p) => p.isNotEmpty)
        .toList();
    for (final p in parts) {
      if (cleanOpt.toLowerCase() == p.toLowerCase()) return true;
      if (cleanOpt.length > 3 &&
          (cleanOpt[1] == '.' || cleanOpt[1] == ')' || cleanOpt[1] == ':') &&
          cleanOpt.substring(2).trim().toLowerCase() == p.toLowerCase()) {
        return true;
      }
      if (p.length == 1) {
        final c = p.toUpperCase().codeUnitAt(0);
        if (c >= 65 && c <= 69 && c - 65 == index) return true;
      }
      final num = int.tryParse(p);
      if (num != null && num == index + 1) return true;
      final strippedOpt = cleanOpt.length > 2 &&
              (cleanOpt[1] == '.' || cleanOpt[1] == ')')
          ? cleanOpt.substring(2).trim()
          : cleanOpt;
      if (strippedOpt.toLowerCase() == p.toLowerCase()) return true;
    }
    return false;
  }

  QuestionDraft _draftFromImportItem(Map<String, dynamic> item) {
    final rawCorrect = (item['correctAnswer'] as String?)?.trim() ?? '';
    // Server kirim options sebagai List<String>; tetap terima Map
    // (tahan format lain) agar opsi tak hilang.
    final optTexts = <String>[
      for (final o in (item['options'] as List<dynamic>? ?? []))
        if (o is String)
          o
        else if (o is Map)
          (o['optionText'] as String? ?? ''),
    ];
    final hasCorrectOption = rawCorrect.isNotEmpty &&
        optTexts.indexed.any(
            (e) => _resolveImportCorrect(e.$2, e.$1, rawCorrect));
    final draft = QuestionDraft(
      item['typeId'] as int? ?? 1,
      question: item['question'] as String? ?? '',
      correctAnswer: item['correctAnswer'] as String? ?? '',
      isRequired: item['isRequired'] as bool? ?? true,
      randomizeOptions: item['randomizeOptions'] as bool? ?? false,
      // Samakan backend ResponseScorer.CountScorable: Points/correctAnswer/isCorrect.
      isScorable: item['points'] != null ||
          rawCorrect.isNotEmpty ||
          hasCorrectOption,
      points: item['points'] as int?,
      questionImage: item['image'] as String? ?? item['questionImage'] as String?,
      questionAudio: item['audio'] as String? ?? item['questionAudio'] as String?,
    );

    for (var i = 0; i < optTexts.length; i++) {
      draft.options.add(
        OptionDraft(
          text: optTexts[i],
          isCorrect: rawCorrect.isNotEmpty &&
              _resolveImportCorrect(optTexts[i], i, rawCorrect),
        ),
      );
    }
    return draft;
  }

  /// Unduh template impor — paritas dengan web `templateDownloadUrl` (`apiService.js:334`).
  /// Template di-generate on-the-fly (rate-limit 10/menit), dibagikan via Share sheet.
  Future<void> downloadTemplate() async {
    if (!AppDebouncer.tryAcquire('form:downloadTemplate')) return;
    final format = await _pickTemplateFormat();
    if (format == null || !mounted) return;
    try {
      final bytes = await FormService.downloadImportTemplate(format);
      if (!mounted) return;
      final xfile = XFile.fromData(
        bytes,
        name: 'import-questions-template.$format',
        mimeType: _mimeForTemplate(format),
      );
      await SharePlus.instance.share(
        ShareParams(files: [xfile], text: 'Template import soal ($format)'),
      );
      if (!mounted) return;
      showAppToast(
        context,
        'Template $format siap dibagikan',
        title: 'Berhasil',
      );
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  static String _mimeForTemplate(String f) => switch (f) {
    'csv' => 'text/csv',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };

  Future<String?> _pickTemplateFormat() => AdaptiveSheet.show<String>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx, _) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pilih format template',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
            ),
          ),
          const SizedBox(height: 8),
          for (final fmt in ['csv', 'xlsx', 'docx', 'pdf'])
            ListTile(
              leading: Icon(Icons.download_outlined,
                  color: Theme.of(ctx).colorScheme.primary),
              title: Text(
                fmt.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                ),
              ),
              subtitle: Text(
                _templateDesc(fmt),
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
              onTap: () => Navigator.pop(ctx, fmt),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  static String _templateDesc(String f) => switch (f) {
    'csv' => 'question,type_id,order,is_required,... (pipe-separated options)',
    'xlsx' => 'Sheet Questions — kolom sama dengan CSV',
    'docx' => 'Question: ... / Options: ... per paragraf',
    'pdf' => 'Petunjuk + contoh soal (read-only)',
    _ => '',
  };
}
