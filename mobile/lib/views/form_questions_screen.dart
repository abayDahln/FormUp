import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'rich_editor.dart';
import 'question_draft.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';
import '../app_router.dart';

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
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Simpan Perubahan?',
          style: TextStyle(fontFamily: kFontBold),
        ),
        content: const Text(
          'Perubahan soal belum disimpan. Simpan atau buang draf?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text(
              'Buang Draf',
              style: TextStyle(color: Color(0xFFC0392B)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text(
              'Simpan',
              style: TextStyle(color: kAuthPrimary),
            ),
          ),
        ],
      ),
    );
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
        _questions.clear();
        for (final q in questions) {
          final draft = QuestionDraft(
            q.typeId,
            id: q.id,
            question: q.question,
            correctAnswer: q.correctAnswer ?? '',
            isRequired: q.isRequired ?? true,
            randomizeOptions: q.randomizeOptions ?? false,
            questionImage: q.questionImage,
            questionAudio: q.questionAudio,
          );
          for (final o in q.options) {
            draft.options.add(OptionDraft(
              id: o.id,
              text: o.optionText,
              isCorrect: o.isCorrect ?? false,
            ));
          }
          _questions.add(draft);
        }
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
    final typeId = await _pickQuestionType();
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

  Future<int?> _pickQuestionType() async {
    final typeId = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFBDC9C8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Pilih Tipe Pertanyaan",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in questionTypes.entries) ...[
              GestureDetector(
                onTap: () => Navigator.pop(context, entry.key),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimarySoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBDC9C8)),
                  ),
                  child: Row(
                    children: [
                      Icon(entry.value.$2, color: kAuthPrimary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        entry.value.$1,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return typeId;
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
    if (_questions.isEmpty) {
      showAuthToast(context, "Tambahkan minimal 1 pertanyaan", isError: true);
      return;
    }
    for (final q in _questions) {
      if (q.question.document.toPlainText().trim().isEmpty) {
        showAuthToast(
          context,
          "Teks pertanyaan tidak boleh kosong",
          isError: true,
        );
        return;
      }
      if (q.hasOptions) {
        if (q.options.isEmpty) {
          showAuthToast(
            context,
            "Tambahkan opsi pada pertanyaan pilihan",
            isError: true,
          );
          return;
        }
        for (final o in q.options) {
          if (o.text.document.toPlainText().trim().isEmpty) {
            showAuthToast(
              context,
              "Teks opsi tidak boleh kosong",
              isError: true,
            );
            return;
          }
        }
      }
    }

    final payload = [
      for (final q in _questions)
        {
          if (q.id != null) 'id': q.id,
          'typeId': q.typeId,
          'question': encodeRichText(q.question),
          'isRequired': q.isRequired,
          'randomizeOptions': q.randomizeOptions,
          if (q.correctAnswer.text.trim().isNotEmpty)
            'correctAnswer': q.correctAnswer.text.trim(),
          if (q.hasOptions)
            'options': [
              for (final o in q.options)
                {
                  'optionText': o.text.document.toPlainText().trim(),
                  'isCorrect': o.isCorrect,
                },
            ],
        },
    ];

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
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xCCBDC9C8)),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.quiz_outlined,
                                color: Colors.grey,
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Belum ada pertanyaan.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (var i = 0; i < _questions.length; i++) ...[
                          _buildQuestionCard(i),
                          const SizedBox(height: 12),
                        ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add, color: kAuthPrimary),
                        label: const Text(
                          "Tambah Pertanyaan",
                          style: TextStyle(color: kAuthPrimary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kAuthPrimary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
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
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text(
                                'Simpan Soal?',
                                style: TextStyle(fontFamily: kFontBold),
                              ),
                              content: const Text(
                                'Soal akan disimpan ke server.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Batal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Simpan',
                                    style: TextStyle(color: kAuthPrimary),
                                  ),
                                ),
                              ],
                            ),
                          );
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

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    final plainText = q.question.document.toPlainText().trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xCCBDC9C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: kPrimarySoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: kAuthPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  questionTypes[q.typeId]?.$1 ?? '',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: kAuthPrimary,
                ),
                tooltip: "Edit soal",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                onPressed: () => _openEditor(q),
              ),
              if (index > 0)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_upward,
                    size: 18,
                    color: Colors.grey,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _moveQuestion(index, -1),
                ),
              if (index < _questions.length - 1)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_downward,
                    size: 18,
                    color: Colors.grey,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _moveQuestion(index, 1),
                ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Color(0xFFC0392B),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() {
                  q.dispose();
                  _questions.removeAt(index);
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (plainText.isEmpty)
            const Text(
              'Belum ada teks pertanyaan.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black45,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            RichTextView(
              text: encodeRichText(q.question),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
        ],
      ),
    );
  }
}
