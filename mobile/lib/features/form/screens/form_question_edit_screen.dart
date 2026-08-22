import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form/controllers/question_validation.dart';
import 'package:form_up/features/form/widgets/question_answer_section.dart';
import 'package:form_up/features/form/widgets/question_confirm_dialogs.dart';
import 'package:form_up/features/form/widgets/question_edit_section_card.dart';
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

  bool _validate() {
    final error = validateQuestionDraft(q);
    if (error != null) {
      showAuthToast(context, error, isError: true);
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
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (exceedsUploadLimit(bytes)) {
        showAuthToast(context, "Gambar maksimal 10 MB", isError: true);
        return;
      }
      // Soal belum punya id → simpan sebagai draf, upload setelah tersimpan.
      if (q.id == null) {
        setState(() {
          q.pendingImageBytes = bytes;
          q.pendingImageName = 'question.jpg';
          q.questionImage = null;
        });
        return;
      }
      setState(() => _uploading = true);
      try {
        final path = await FormService.uploadQuestionImage(
          widget.formId!,
          q.id!,
          bytes,
          'question.jpg',
        );
        if (!mounted) return;
        setState(() => q.questionImage = path);
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  Future<void> _pickQuestionAudio() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      if (file == null || file.bytes == null) return;
      if (!mounted) return;
      if (exceedsUploadLimit(file.bytes!)) {
        showAuthToast(context, "Audio maksimal 10 MB", isError: true);
        return;
      }
      // Soal belum punya id → simpan sebagai draf, upload setelah tersimpan.
      if (q.id == null) {
        setState(() {
          q.pendingAudioBytes = file.bytes;
          q.pendingAudioName = file.name;
          q.questionAudio = null;
        });
        return;
      }
      setState(() => _uploading = true);
      try {
        final path = await FormService.uploadQuestionAudio(
          widget.formId!,
          q.id!,
          file.bytes!,
          file.name,
        );
        if (!mounted) return;
        setState(() => q.questionAudio = path);
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xCCBDC9C8)),
        ),
        title: const Text(
          'Edit Soal',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
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
          AuthBackground(
            child: SafeArea(
              child: ValueListenableBuilder<ActiveRichEditor?>(
                valueListenable: activeRichEditor,
                builder: (context, active, _) {
                  final toolbarVisible = active != null;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      22,
                      4,
                      22,
                      toolbarVisible ? 110 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        QuestionEditSectionCard(
                          title: 'Soal',
                          icon: Icons.help_outline,
                          child: QuestionTextSection(
                            draft: q,
                            preview: _preview,
                            onPreviewChanged: (v) =>
                                setState(() => _preview = v),
                            onTypeChanged: _onTypeChanged,
                          ),
                        ),
                        const SizedBox(height: 16),
                        QuestionEditSectionCard(
                          title: 'Jawaban',
                          icon: Icons.rule,
                          child: QuestionAnswerSection(
                            draft: q,
                            onChanged: () => setState(() {}),
                          ),
                        ),
                        const SizedBox(height: 16),
                        QuestionEditSectionCard(
                          title: 'Media',
                          icon: Icons.attach_file,
                          child: QuestionMediaSection(
                            draft: q,
                            uploading: _uploading,
                            onPickImage: _pickQuestionImage,
                            onPickAudio: _pickQuestionAudio,
                            onChanged: () => setState(() {}),
                          ),
                        ),
                        const SizedBox(height: 16),
                        QuestionEditSectionCard(
                          title: 'Pengaturan',
                          icon: Icons.tune,
                          child: QuestionRequiredSwitch(
                            value: q.isRequired,
                            onChanged: (v) =>
                                setState(() => q.isRequired = v),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AuthPrimaryButton(
                          label: "Simpan Soal",
                          onPressed: _save,
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
