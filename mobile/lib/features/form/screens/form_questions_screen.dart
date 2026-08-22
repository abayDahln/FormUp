import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form/controllers/question_payload_builder.dart';
import 'package:form_up/features/form/controllers/question_validation.dart';
import 'package:form_up/features/form/widgets/add_question_button.dart';
import 'package:form_up/features/form/widgets/question_confirm_dialogs.dart';
import 'package:form_up/features/form/widgets/question_list_card.dart';
import 'package:form_up/features/form/widgets/question_type_picker_sheet.dart';
import 'package:form_up/features/form/widgets/questions_empty_state.dart';

/// Kelola daftar soal form: tambah/edit/hapus/urutkan, lalu simpan.
class FormQuestionsScreen extends StatefulWidget {
  final int? formId;
  final bool isNew;

  const FormQuestionsScreen({super.key, required this.formId, this.isNew = false});

  @override
  State<FormQuestionsScreen> createState() => _FormQuestionsScreenState();
}

class _FormQuestionsScreenState extends State<FormQuestionsScreen> {
  final List<QuestionDraft> _questions = [];
  List<QuestionDraft> _baseline = [];
  AppRouterDelegate? _router;
  bool _loading = true;
  bool _saving = false;
  double? _progress;

  bool get _hasChanges {
    if (_questions.length != _baseline.length) return true;
    for (var i = 0; i < _questions.length; i++) {
      if (!_questions[i].sameAs(_baseline[i])) return true;
    }
    return false;
  }

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
    final typeId = await showQuestionTypePicker(context);
    if (typeId == null || !mounted) return;
    final draft = QuestionDraft(typeId);
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
    await AppRouter.of(context).push(AppPage.formQuestionEdit, {
      'formId': widget.formId,
      'draft': draft,
    });
    if (mounted) setState(() {});
  }

  void _moveQuestion(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _questions.length) return;
    setState(() {
      final q = _questions.removeAt(index);
      _questions.insert(newIndex, q);
    });
  }

  Future<void> _save() async {
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
      // setelah server balikkan id. Id baru = item di respons yang id-nya
      // tidak termasuk id lama, berurutan sesuai urutan daftar.
      final knownIds = _questions.map((q) => q.id).whereType<int>().toSet();
      final newSaved =
          saved.where((m) => !knownIds.contains(m['id'] as int?)).toList();
      final uploads = <(QuestionDraft, Uint8List, String, bool)>[];
      var newIndex = 0;
      for (final q in _questions) {
        if (q.pendingImageBytes == null && q.pendingAudioBytes == null) {
          continue;
        }
        final savedId = q.id ?? newSaved[newIndex]['id'] as int?;
        if (savedId == null) continue;
        q.id ??= savedId;
        newIndex++;
        if (q.pendingImageBytes != null) {
          uploads.add((q, q.pendingImageBytes!, q.pendingImageName ?? 'question.jpg', true));
        }
        if (q.pendingAudioBytes != null) {
          uploads.add((q, q.pendingAudioBytes!, q.pendingAudioName ?? 'audio', false));
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
      if (mounted) setState(() {
        _saving = false;
        _progress = null;
      });
    }
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
          "Kelola Soal",
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
              absorbing: _saving,
              child: AuthBackground(
                child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_questions.isEmpty)
                        const QuestionsEmptyState()
                      else
                        for (var i = 0; i < _questions.length; i++) ...[
                          QuestionListCard(
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
                          const SizedBox(height: 12),
                        ],
                      const SizedBox(height: 8),
                      AddQuestionButton(onPressed: _addQuestion),
                      const SizedBox(height: 20),
                      AuthPrimaryButton(
                        label: _saving ? "Menyimpan..." : "Simpan Soal",
                        loading: _saving,
                        progress: _progress,
                        onPressed: () async {
                          if (!_hasChanges) {
                            await _save();
                            return;
                          }
                          final confirmed = await showSaveConfirmDialog(context);
                          if (confirmed == true) await _save();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }
}
