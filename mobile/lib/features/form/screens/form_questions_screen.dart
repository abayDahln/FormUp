import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/utils/action_debouncer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:form_up/core/widgets/app_toast.dart' hide showAuthToast;
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form/controllers/question_payload_builder.dart';
import 'package:form_up/features/form/controllers/question_validation.dart';
import 'package:form_up/features/form/widgets/question_confirm_dialogs.dart';
import 'package:form_up/features/form/widgets/question_list_card.dart';
import 'package:form_up/features/form/widgets/questions_empty_state.dart';

/// Kelola daftar soal form: tambah/edit/hapus/urutkan, lalu simpan.
class FormQuestionsScreen extends StatefulWidget {
  final int? formId;
  final bool isNew;

  const FormQuestionsScreen({
    super.key,
    required this.formId,
    this.isNew = false,
  });

  @override
  State<FormQuestionsScreen> createState() => _FormQuestionsScreenState();
}

class _FormQuestionsScreenState extends State<FormQuestionsScreen> {
  static const _allowedImportExt = ['pdf', 'docx', 'xlsx', 'xls', 'csv'];

  final List<QuestionDraft> _questions = [];
  List<QuestionDraft> _baseline = [];
  AppRouterDelegate? _router;
  bool _loading = true;
  bool _saving = false;
  bool _importing = false;
  double? _progress;

  bool get _hasChanges {
    if (_questions.length != _baseline.length) return true;
    for (var i = 0; i < _questions.length; i++) {
      if (!_questions[i].sameAs(_baseline[i])) return true;
    }
    return false;
  }

  /// Unduh template impor — paritas dengan web `templateDownloadUrl` (`apiService.js:334`).
  /// Template di-generate on-the-fly (rate-limit 10/menit), dibagikan via Share sheet.
  Future<void> _downloadTemplate() async {
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

  Future<String?> _pickTemplateFormat() => showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
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
              leading: const Icon(Icons.download_outlined, color: kAuthPrimary),
              title: Text(
                fmt.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                ),
              ),
              subtitle: Text(
                _templateDesc(fmt),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
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

  @override
  void initState() {
    super.initState();
    if (widget.formId != null) _loadQuestions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= AppRouter.of(context);
    _router!.pushBackGuard(_confirmExit);
  }

  @override
  void dispose() {
    _router?.popBackGuard();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  /// Konfirmasi keluar: simpan / buang draf / batal.
  Future<bool> _confirmExit() async {
    if (!_hasChanges) return true;
    final choice = await showExitConfirmDialog(context);
    if (!mounted) return false;
    if (choice == 'discard') return true;
    if (choice == 'save') {
      await _save();
      return false; // _save yang menutup screen.
    }
    return false;
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    try {
      final questions = await FormService.getQuestions(widget.formId!);
      if (!mounted) return;
      setState(() {
        _questions
          ..clear()
          ..addAll(draftsFromQuestions(questions));
        _baseline = [for (final q in _questions) q.copy()];
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addQuestion() async {
    final draft = QuestionDraft(1);
    setState(() => _questions.add(draft));
    await _openEditor(draft);
    // Draf baru yang dibuang (tidak disimpan) dihapus dari daftar.
    if (mounted && draft.question.document.toPlainText().trim().isEmpty) {
      setState(() {
        _questions.remove(draft);
        draft.dispose();
      });
    }
  }

  Future<void> _openEditor(QuestionDraft draft) async {
    await AppRouter.of(
      context,
    ).push(AppPage.formQuestionEdit, {'formId': widget.formId, 'draft': draft});
    if (mounted) setState(() {});
  }

  /// Impor soal dari file .docx/.pdf/.xlsx/.csv via endpoint backend.
  /// Gambar di dalam docx/pdf ikut terekstrak ke soal.
  /// Alur: pilih file → preview (parse & validasi) → konfirmasi → save.
  Future<void> _importSoal() async {
    if (!AppDebouncer.tryAcquire('form:importSoal')) return;
    if (widget.formId == null || _saving || _importing) return;

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedImportExt,
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || !mounted) return;
    final bytes = file.bytes;
    if (bytes == null) {
      showAuthToast(context, "Gagal membaca file", isError: true);
      return;
    }

    setState(() => _importing = true);
    try {
      // 1) Preview: parse & validasi saja, belum menyimpan apa pun
      final preview = await FormService.previewQuestionImport(
        widget.formId!,
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

      // 3) Simpan sungguhan ke database
      final result = await FormService.saveQuestionImport(
        widget.formId!,
        bytes,
        file.name,
      );
      if (!mounted) return;
      final imported = result['totalImported'] as int? ?? 0;
      final skipped = result['totalSkipped'] as int? ?? 0;
      showAppToast(
        context,
        "$imported soal diimpor${skipped > 0 ? ", $skipped dilewati" : ""}",
        type: imported > 0 ? ToastType.success : ToastType.warning,
        title: "Impor Selesai",
      );
      await _loadQuestions();
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _importing = false);
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

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: Colors.black87,
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                itemCount: questions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final q = questions[i];
                  final imageDataUri = q['image'] as String?;
                  final options = (q['options'] as List<dynamic>? ?? [])
                      .whereType<String>()
                      .toList();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kAuthFieldFill,
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
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: kFontBold,
                            color: Colors.black87,
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
                        // Teks opsi jawaban hasil parse
                        if (options.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          for (final opt in options)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                "• $opt",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
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
                        child: const Text(
                          'Batal',
                          style: TextStyle(color: Colors.black54),
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

  Widget _previewChip(String label, [Color color = kAuthPrimary]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          color: color,
        ),
      ),
    );
  }

  void _moveQuestion(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _questions.length) return;
    setState(() {
      final q = _questions.removeAt(index);
      _questions.insert(newIndex, q);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final q = _questions.removeAt(oldIndex);
      _questions.insert(newIndex, q);
    });
  }

  Future<void> _save() async {
    if (!AppDebouncer.tryAcquire('form:saveQuestions')) return;
    if (_saving) return;
    final error = validateQuestionsList(_questions);
    if (error != null) {
      showAuthToast(context, error, isError: true);
      return;
    }

    final payload = buildQuestionsPayload(_questions);

    setState(() => _saving = true);
    void setProgress(double p) {
      if (mounted) setState(() => _progress = p);
    }

    try {
      final formId = widget.formId;
      if (formId == null) return;
      setProgress(0.1);
      final saved = widget.isNew
          ? await FormService.saveQuestions(formId, payload)
          : await FormService.updateQuestions(formId, payload);
      setProgress(0.5);

      // Queue upload media draf: soal baru belum punya id, jadi upload
      // setelah server balikkan id. Server kembalikan daftar berurutan sesuai questionOrder.
      for (var i = 0; i < _questions.length && i < saved.length; i++) {
        _questions[i].id ??= saved[i]['id'] as int?;
      }
      final uploads = <(QuestionDraft, Uint8List, String, bool)>[];
      for (final q in _questions) {
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
          showAuthToast(context, "Media maksimal 10 MB", isError: true);
          setState(() => _saving = false);
          return;
        }
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
          // Media gagal upload — soal tetap tersimpan, media dibatalkan.
          showAuthToast(
            context,
            "Gagal upload media (${AuthService.errorMessage(e)})",
            isError: true,
          );
        }
        setProgress(0.5 + (0.5 * (i + 1) / uploads.length));
      }
      if (!mounted) return;
      setProgress(1.0);
      AppRouter.of(context).pop(formId);
      showAuthToast(context, "Soal berhasil disimpan");
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted)
        setState(() {
          _saving = false;
          _progress = null;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xCCBDC9C8))),
        title: const Text(
          "Kelola Soal",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () async {
            final allow = await _confirmExit();
            if (!allow) return;
            if (!mounted) return;
            _router!.pop();
          },
        ),
        actions: [
          // Tombol simpan di header, di samping menu
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : FilledButton(
                    onPressed: () async {
                      if (!_hasChanges) {
                        await _save();
                        return;
                      }
                      final confirmed = await showSaveConfirmDialog(context);
                      if (confirmed == true) await _save();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Simpan'),
                  ),
          ),
          // M3 menu: Impor Soal & Unduh Template — https://m3.material.io/components/menus/overview
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MenuAnchor(
              builder: (context, controller, child) => IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.black87),
                tooltip: 'Opsi',
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
              ),
              menuChildren: [
                MenuItemButton(
                  leadingIcon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: AppLoadingIndicator.inline(),
                        )
                      : const Icon(Icons.upload_file_outlined, size: 20),
                  onPressed: (widget.formId == null || _saving || _importing)
                      ? null
                      : _importSoal,
                  child: Text(_importing ? 'Mengimpor...' : 'Impor Soal'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.download_outlined, size: 20),
                  onPressed: _downloadTemplate,
                  child: const Text('Unduh Template Import'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingOverlay()
          : Stack(
              children: [
                AbsorbPointer(
                  absorbing: _saving || _importing,
                  child: AuthBackground(
                plain: true,
                child: SafeArea(
                  child: _questions.isEmpty
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              QuestionsEmptyState(),
                              SizedBox(height: 80),
                            ],
                          ),
                        )
                      : Stack(
                          children: [
                            ReorderableListView.builder(
                              padding: const EdgeInsets.fromLTRB(22, 4, 22, 96),
                              itemCount: _questions.length,
                              onReorder: _onReorder,
                              buildDefaultDragHandles: false,
                              proxyDecorator: (child, index, animation) =>
                                  Transform.scale(
                                    scale: 0.98,
                                    child: Opacity(
                                      opacity: 0.9,
                                      child: Material(
                                        color: Colors.transparent,
                                        elevation: 0,
                                        child: child,
                                      ),
                                    ),
                                  ),
                              itemBuilder: (context, i) =>
                                  ReorderableDelayedDragStartListener(
                                    key: ValueKey(_questions[i]),
                                    index: i,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: QuestionListCard(
                                        index: i,
                                        totalCount: _questions.length,
                                        question: _questions[i],
                                          onEdit: () => _openEditor(_questions[i]),
                                          onMoveUp: () => _moveQuestion(i, -1),
                                          onMoveDown: () => _moveQuestion(i, 1),
                                          onDelete: () => setState(() {
                                            _questions[i].dispose();
                                            _questions.removeAt(i);
                                          }),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
                // Indikator M3 wavy smooth full kiri ke kanan saat menyimpan
                if (_saving)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AppLoadingIndicator.linear(),
                  ),
                if (_importing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.15),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppLoadingIndicator.contained(),
                            SizedBox(height: 16),
                            Text(
                              'Memproses file...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: SizedBox(
        width: 68,
        height: 68,
        child: FloatingActionButton(
          onPressed: _addQuestion,
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          tooltip: 'Tambah Soal',
          child: const Icon(Icons.add, size: 32),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

/// Tombol impor soal dari file — sejajar dengan tombol tambah pertanyaan.
// class _ImportSoalButton extends StatelessWidget {
//   final bool importing;
//   final bool disabled;
//   final VoidCallback onPressed;

//   const _ImportSoalButton({
//     required this.importing,
//     required this.disabled,
//     required this.onPressed,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final enabled = !importing && !disabled;
//     return ElevatedButton.icon(
//       onPressed: enabled ? onPressed : null,
//       icon: importing
//           ? const SizedBox(
//               width: 18,
//               height: 18,
//               child: AppLoadingIndicator.inline(),
//             )
//           : const Icon(Icons.upload_file_outlined, size: 20),
//       label: Text(
//         importing ? "Mengimpor..." : "Impor Soal",
//         maxLines: 1,
//         overflow: TextOverflow.ellipsis,
//         style: TextStyle(
//           fontWeight: FontWeight.bold,
//           fontFamily: kFontBold,
//         ),
//       ),
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.white,
//         disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
//         side: BorderSide(
//           color: enabled ? kAuthPrimary : kAuthPrimary.withValues(alpha: 0.4),
//         ),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//         padding: const EdgeInsets.symmetric(vertical: 14),
//         foregroundColor: kAuthPrimary,
//       ),
//     );
//   }
// }
