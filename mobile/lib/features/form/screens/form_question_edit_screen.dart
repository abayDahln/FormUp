import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:form_up/core/widgets/progress_indicator.dart' as progress;
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form/controllers/question_validation.dart';
import 'package:form_up/features/form/widgets/question_answer_section.dart';
import 'package:form_up/features/form/widgets/question_confirm_dialogs.dart';
import 'package:form_up/features/form/widgets/question_image_source_sheet.dart';
import 'package:form_up/features/form/widgets/question_media_section.dart';
import 'package:form_up/features/form/widgets/question_required_switch.dart';
import 'package:form_up/features/form/widgets/question_text_section.dart';

/// Edit satu soal (detail): tipe, teks, opsi, kunci jawaban, media, wajib.
class FormQuestionEditScreen extends StatefulWidget {
  final int? formId;
  final QuestionDraft draft;

  const FormQuestionEditScreen({
    super.key,
    required this.formId,
    required this.draft,
  });

  @override
  State<FormQuestionEditScreen> createState() => _FormQuestionEditScreenState();
}

class _FormQuestionEditScreenState extends State<FormQuestionEditScreen> {
  late final QuestionDraft _working;
  AppRouterDelegate? _router;
  bool _preview = false;
  bool _uploading = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _questionFieldKey = GlobalKey();
  final GlobalKey _answerSectionKey = GlobalKey();

  QuestionDraft get q => _working;

  @override
  void initState() {
    super.initState();
    // Edit di salinan; baru ditulis ke draf asli saat "Simpan".
    _working = widget.draft.copy();
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
    _scrollController.dispose();
    _working.dispose();
    super.dispose();
  }

  Future<bool> _confirmExit() async {
    // Tidak ada perubahan → langsung izinkan keluar tanpa dialog.
    if (_working.sameAs(widget.draft)) return true;
    final choice = await showExitConfirmDialog(context);
    if (!mounted) return false;
    if (choice == 'discard') return true;
    if (choice == 'save') {
      if (!_validate()) return false;
      _commit();
      return true;
    }
    return false;
  }

  /// Auto-scroll ke field yang gagal validasi
  Future<void> _scrollToError(String error) async {
    final toAnswer = error.toLowerCase().contains('opsi');
    final ctx = toAnswer
        ? _answerSectionKey.currentContext
        : _questionFieldKey.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.15,
      );
    }
  }

  bool _validate() {
    final error = validateQuestionDraft(q);
    if (error != null) {
      showAuthToast(context, error, isError: true);
      _scrollToError(error);
      return false;
    }
    return true;
  }

  void _commit() {
    widget.draft.copyFrom(_working);
  }

  Future<void> _save() async {
    if (!_validate()) return;
    if (!_working.sameAs(widget.draft)) {
      final confirmed = await showQuestionEditSaveDialog(context);
      if (confirmed != true || !mounted) return;
    }
    _commit();
    AppRouter.of(context).pop();
  }

  Future<void> _pickQuestionImage() async {
    final source = await showQuestionImageSourceSheet(context);
    if (source == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) {
        if (mounted) setState(() => _uploading = false);
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (exceedsUploadLimit(bytes)) {
        showAuthToast(context, "Gambar maksimal 10 MB", isError: true);
        return;
      }
      setState(() {
        q.pendingImageBytes = bytes;
        q.pendingImageName = 'question.jpg';
        // Nilai final questionImage baru ditetapkan setelah soal disimpan.
        q.questionImage = null;
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickQuestionAudio() async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) return;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (_) {
          bytes = null;
        }
      }
      if (bytes == null) {
        if (!mounted) return;
        showAuthToast(context, "Gagal membaca file audio", isError: true);
        return;
      }
      if (!mounted) return;
      if (exceedsUploadLimit(bytes)) {
        showAuthToast(context, "Audio maksimal 10 MB", isError: true);
        return;
      }
      setState(() {
        q.pendingAudioBytes = bytes;
        q.pendingAudioName = file.name;
        // Nilai final questionAudio baru ditetapkan setelah soal disimpan.
        q.questionAudio = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : e.toString().replaceFirst('Exception: ', '');
      showAuthToast(context, msg.isEmpty ? "Gagal memproses audio" : msg, isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _onTypeChanged(int v) {
    setState(() {
      q.typeId = v;
      if (!q.hasOptions) {
        for (final o in q.options) {
          o.text.dispose();
        }
        q.options.clear();
      }
    });
  }

  /// Grup isi kartu editor: phone 1 kolom identik; ≥840 dua kolom
  /// (kiri: teks + jawaban, kanan: pengaturan + media).
  Widget _buildWideGroups(
      BuildContext context, ColorScheme cs, QuestionDraft q) {
    Widget sectionTitle(IconData icon, String text) => Row(
          children: [
            Icon(icon, size: 18, color: cs.primary),
            SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: cs.onSurface,
              ),
            ),
          ],
        );
    final textAndAnswer = [
      QuestionTextSection(
        questionFieldKey: _questionFieldKey,
        draft: q,
        preview: _preview,
        onPreviewChanged: (v) => setState(() => _preview = v),
        onTypeChanged: _onTypeChanged,
      ),
      const Divider(height: 32),
      sectionTitle(Icons.rule, 'Jawaban'),
      const SizedBox(height: 14),
      QuestionAnswerSection(
        optionsKey: _answerSectionKey,
        draft: q,
        onChanged: () => setState(() {}),
      ),
    ];
    final settingsAndMedia = [
      sectionTitle(Icons.tune, 'Pengaturan'),
      const SizedBox(height: 14),
      QuestionRequiredSwitch(
        value: q.isRequired,
        onChanged: (v) => setState(() {
          // Samakan web: isRequired independen dari
          // isScorable/kunci/poin. Jangan hapus kunci.
          q.isRequired = v;
        }),
      ),
      const Divider(height: 32),
      sectionTitle(Icons.attach_file, 'Media'),
      const SizedBox(height: 14),
      QuestionMediaSection(
        draft: q,
        uploading: _uploading,
        onPickImage: _pickQuestionImage,
        onPickAudio: _pickQuestionAudio,
        onChanged: () => setState(() {}),
      ),
    ];
    if (!isExpanded(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...textAndAnswer,
          const SizedBox(height: 18),
          ...settingsAndMedia,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: textAndAnswer,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: settingsAndMedia,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape:  Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
        title:  Text(
          'Edit Soal',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
          ),
        ),
        leading: IconButton(
          icon:  Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () async {
            final allow = await _confirmExit();
            if (!allow) return;
            if (!mounted) return;
            _router!.pop();
          },
        ),
      ),
      body: Stack(
        children: [
          if (_uploading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: progress.ProgressIndicator.linear(
                semanticsLabel: 'Memuat media',
              ),
            ),
          AuthBackground(plain: true,
            child: SafeArea(
              child: ValueListenableBuilder<ActiveRichEditor?>(
                valueListenable: activeRichEditor,
                builder: (context, active, _) {
                  final toolbarVisible = active != null;
                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: centerPad(
                      context,
                      base: EdgeInsets.fromLTRB(
                        22,
                        16,
                        22,
                        toolbarVisible ? 110 : 24,
                      ),
                      wideMaxWidth: 900,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: _buildWideGroups(context, cs, q),
                        ),
                        const SizedBox(height: 24),
                        AuthPrimaryButton(
                          label: "Simpan Soal",
                          loading: _uploading,
                          onPressed: _uploading ? null : _save,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const FloatingRichToolbar(),
        ],
      ),
    );
  }
}
