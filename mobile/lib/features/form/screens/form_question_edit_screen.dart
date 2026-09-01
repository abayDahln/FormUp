import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
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
      setState(() {
        q.pendingImageBytes = bytes;
        q.pendingImageName = 'question.jpg';
        // Nilai final questionImage baru ditetapkan setelah soal disimpan.
        q.questionImage = null;
      });
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
      backgroundColor: kAppBg,
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
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
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
              child: AppLoadingIndicator.linear(),
            ),
          AuthBackground(plain: true,
            child: SafeArea(
              child: ValueListenableBuilder<ActiveRichEditor?>(
                valueListenable: activeRichEditor,
                builder: (context, active, _) {
                  final toolbarVisible = active != null;
                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      22,
                      4,
                      22,
                      toolbarVisible ? 110 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xCCBDC9C8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              QuestionTextSection(
                                questionFieldKey: _questionFieldKey,
                                draft: q,
                                preview: _preview,
                                onPreviewChanged: (v) => setState(() => _preview = v),
                                onTypeChanged: _onTypeChanged,
                              ),
                              const Divider(height: 32),
                              Row(
                                children: const [
                                  Icon(Icons.tune, size: 18, color: kAuthPrimary),
                                  SizedBox(width: 8),
                                  Text(
                                    'Pengaturan',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: kFontBold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              QuestionRequiredSwitch(
                                value: q.isRequired,
                                onChanged: (v) => setState(() {
                                  q.isRequired = v;
                                  if (!v) {
                                    q.isScorable = false;
                                    q.points = null;
                                    q.correctAnswer.clear();
                                    for (final o in q.options) {
                                      o.isCorrect = false;
                                    }
                                  }
                                }),
                              ),
                              const SizedBox(height: 18),
                              if (q.isRequired)
                                ...[
                                  Row(
                                    children: const [
                                      Icon(Icons.rule, size: 18, color: kAuthPrimary),
                                      SizedBox(width: 8),
                                      Text(
                                        'Jawaban',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: kFontBold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  QuestionAnswerSection(
                                    optionsKey: _answerSectionKey,
                                    draft: q,
                                    onChanged: () => setState(() {}),
                                  ),
                                ],
                              const Divider(height: 32),
                              Row(
                                children: const [
                                  Icon(Icons.attach_file, size: 18, color: kAuthPrimary),
                                  SizedBox(width: 8),
                                  Text('Media',
                                      style: TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.bold, fontFamily: kFontBold, color: Colors.black87)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              QuestionMediaSection(
                                draft: q,
                                uploading: _uploading,
                                onPickImage: _pickQuestionImage,
                                onPickAudio: _pickQuestionAudio,
                                onChanged: () => setState(() {}),
                              ),
                            ],
                          ),
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
