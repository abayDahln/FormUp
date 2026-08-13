import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'auth_widgets.dart';
import 'rich_editor.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';
import '../app_router.dart';

class _OptionDraft {
  int? id;
  final QuillController text;
  bool isCorrect;

  _OptionDraft({this.id, String text = '', this.isCorrect = false})
      : text = richTextController(text);
}

class _QuestionDraft {
  int? id;
  int typeId;
  final QuillController question;
  final TextEditingController correctAnswer;
  bool isRequired;
  bool randomizeOptions;
  final List<_OptionDraft> options;
  String? questionImage;
  String? questionAudio;

  _QuestionDraft(
    this.typeId, {
    this.id,
    String question = '',
    String correctAnswer = '',
    this.isRequired = true,
    this.randomizeOptions = false,
    this.questionImage,
    this.questionAudio,
  })  : question = richTextController(question),
        correctAnswer = TextEditingController(text: correctAnswer),
        options = [];

  /// Multiple Choice & Checkbox punya opsi (dengan isCorrect).
  bool get hasOptions => typeId == 2 || typeId == 3;

  void dispose() {
    question.dispose();
    correctAnswer.dispose();
    for (final o in options) {
      o.text.dispose();
    }
  }
}

/// Tipe pertanyaan (ID dari tabel referensi QuestionType).
/// 1=Essay, 2=Multiple Choice, 3=Checkbox, 4=Date Time, 5=True False.
const _types = {
  1: ('Essay', Icons.short_text),
  2: ('Pilihan Ganda', Icons.radio_button_checked),
  3: ('Checkbox', Icons.check_box_outlined),
  4: ('Tanggal & Waktu', Icons.calendar_today_outlined),
  5: ('Benar/Salah', Icons.check_circle_outline),
};

class FormMakerScreen extends StatefulWidget {
  /// ID form saat mode edit. `null` = buat form baru.
  final int? formId;

  const FormMakerScreen({super.key, this.formId});

  @override
  State<FormMakerScreen> createState() => _FormMakerScreenState();
}

class _FormMakerScreenState extends State<FormMakerScreen> {
  final QuillController _titleController = richTextController(null);
  final QuillController _descController = richTextController(null);
  final _timerController = TextEditingController();
  final _tokenController = TextEditingController();
  final _customLinkController = TextEditingController();
  final List<_QuestionDraft> _questions = [];
  bool _loading = false;
  bool _saving = false;

  // Pengaturan form (FormSetting).
  int _formTypeId = 1;
  bool _showScore = false;
  bool _randomizeQuestions = false;
  bool _oneResponse = false;
  bool _requiredLogin = false;
  DateTime? _openFormTime;
  DateTime? _closeFormTime;

  // Banner form (bannerImage dari server / bytes gambar baru).
  String? _bannerImage;
  Uint8List? _newBanner;
  bool _bannerCleared = false;

  // Index soal yang sedang upload gambar/audio (untuk indikator loading).
  int? _uploadingQuestion;

  // Indeks soal yang sedang dalam mode pratinjau (live preview).
  int? _previewQuestion;

  // Info berbagi form (URL publik + QR) — diisi saat kartu Share dibuka.
  Map<String, dynamic>? _shareInfo;
  Uint8List? _shareQr;
  bool _shareLoading = false;

  /// open_form_time hanya bisa di-set sekali; kalau sudah ada di server,
  /// jangan kirim ulang saat save (backend menolak dengan 400).
  bool _openTimeAlreadySet = false;

  bool get _isEdit => widget.formId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadForm();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _timerController.dispose();
    _tokenController.dispose();
    _customLinkController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _loadForm() async {
    setState(() => _loading = true);
    try {
      final form = await FormService.getForm(widget.formId!);
      final questions = await FormService.getQuestions(widget.formId!);
      if (!mounted) return;

      final settings = form['settings'] as Map<String, dynamic>?;
      final rawOpen = settings?['openFormTime'] as String?;
      final rawClose = settings?['closeFormTime'] as String?;
      setState(() {
        _titleController.document = richDocument(form['title'] as String?);
        _descController.document = richDocument(form['description'] as String?);
        _bannerImage = form['bannerImage'] as String?;
        _newBanner = null;
        _bannerCleared = false;
        _formTypeId = (settings?['formTypeId'] as int?) ?? 1;
        _showScore = settings?['showScore'] == true;
        _randomizeQuestions = settings?['randomizeQuestions'] == true;
        _oneResponse = settings?['oneResponse'] == true;
        _requiredLogin = settings?['requiredLogin'] == true;
        _openFormTime =
            rawOpen != null ? DateTime.tryParse(rawOpen)?.toLocal() : null;
        _closeFormTime =
            rawClose != null ? DateTime.tryParse(rawClose)?.toLocal() : null;
        _openTimeAlreadySet = _openFormTime != null;
        if (settings?['timerDuration'] is int) {
          _timerController.text =
              '${settings!['timerDuration']}';
        }
        _customLinkController.text = form['formLink'] as String? ?? '';

        _questions.clear();
        for (final q in questions) {
          final draft = _QuestionDraft(
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
            draft.options.add(_OptionDraft(
              id: o.id,
              text: o.optionText,
              isCorrect: o.isCorrect ?? false,
            ));
          }
          _questions.add(draft);
        }
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addQuestion(int typeId) async {
    setState(() => _questions.add(_QuestionDraft(typeId)));
  }

  Future<void> _pickQuestionType() async {
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
            for (final entry in _types.entries) ...[
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
    if (typeId != null) await _addQuestion(typeId);
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.document.toPlainText().trim();
    if (title.isEmpty) {
      showAuthToast(context, "Judul form wajib diisi", isError: true);
      return;
    }
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

    final questionsPayload = [
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
                  'optionText': encodeRichText(o.text),
                  'isCorrect': o.isCorrect,
                },
            ],
        },
    ];

    final settingsPayload = <String, dynamic>{
      'formTypeId': _formTypeId,
      'showScore': _showScore,
      'randomizeQuestions': _randomizeQuestions,
      'oneResponse': _oneResponse,
      'requiredLogin': _requiredLogin,
      if (_timerController.text.trim().isNotEmpty)
        'timerDuration': int.tryParse(_timerController.text.trim()),
      if (_tokenController.text.trim().isNotEmpty)
        'formToken': _tokenController.text.trim(),
      if (_openFormTime != null && !_openTimeAlreadySet)
        'openFormTime': _openFormTime!.toUtc().toIso8601String(),
      if (_closeFormTime != null)
        'closeFormTime': _closeFormTime!.toUtc().toIso8601String(),
    };

    setState(() => _saving = true);
    try {
      final customLink = _sanitizeLink(_customLinkController.text);
      final int formId;
      if (_isEdit) {
        formId = widget.formId!;
        await FormService.updateForm(
          formId,
          title: encodeRichText(_titleController),
          description: encodeRichText(_descController),
          formLink: customLink.isEmpty ? null : customLink,
        );
        await FormService.updateQuestions(formId, questionsPayload);
      } else {
        formId = await FormService.createForm(
          title: encodeRichText(_titleController),
          description: encodeRichText(_descController),
        );
        if (customLink.isNotEmpty) {
          await FormService.updateForm(formId, formLink: customLink);
        }
        await FormService.saveQuestions(formId, questionsPayload);
      }
      await FormService.updateSettings(formId, settingsPayload);

      if (_newBanner != null) {
        await FormService.uploadBanner(formId, _newBanner!, 'banner.jpg');
      } else if (_bannerCleared && _isEdit) {
        await FormService.updateForm(formId, bannerImage: '');
      }

      if (!mounted) return;
      AppRouter.of(context).pop(formId);
      showAuthToast(
        context,
        _isEdit ? "Form berhasil diperbarui" : "Form berhasil dibuat",
      );
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _moveQuestion(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _questions.length) return;
    setState(() {
      final q = _questions.removeAt(index);
      _questions.insert(newIndex, q);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthBg,
      appBar: AppBar(
        backgroundColor: kAuthBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _isEdit ? "Edit Form" : "Buat Form",
          style: const TextStyle(
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => AppRouter.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                AuthBackground(
                  child: SafeArea(
                    child: ValueListenableBuilder<ActiveRichEditor?>(
                      valueListenable: activeRichEditor,
                      builder: (context, active, _) {
                        // Toolbar muncul selama ada editor rich yang fokus,
                        // tidak bergantung pada keyboard yang terbuka.
                        final toolbarVisible = active != null;
                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            4,
                            22,
                            toolbarVisible ? 80 : 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildFormHeader(),
                              const SizedBox(height: 16),
                              _buildSettingsCard(),
                              const SizedBox(height: 16),
                              for (var i = 0; i < _questions.length; i++) ...[
                                _buildQuestionCard(i),
                                const SizedBox(height: 12),
                              ],
                              _buildAddQuestionButton(),
                              if (_isEdit) ...[
                                const SizedBox(height: 16),
                                _buildShareCard(),
                              ],
                              const SizedBox(height: 24),
                              AuthPrimaryButton(
                                label: _saving ? "Menyimpan..." : "Simpan Form",
                                loading: _saving,
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

  Widget _buildFormHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xCCBDC9C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Judul Form",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: kAuthPrimary,
            ),
          ),
          const SizedBox(height: 8),
          RichTextEditor(
            controller: _titleController,
            hint: "Contoh: Survey Kepuasan",
            minHeight: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            "Deskripsi",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: kAuthPrimary,
            ),
          ),
          const SizedBox(height: 8),
          RichTextEditor(
            controller: _descController,
            hint: "Jelaskan tujuan form Anda (opsional)",
            minHeight: 60,
          ),
          const SizedBox(height: 16),
          _buildBannerField(),
        ],
      ),
    );
  }

  Widget _buildBannerField() {
    final hasImage = _newBanner != null || (_bannerImage?.isNotEmpty ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Banner Form",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: kAuthPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 140,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6E7979)),
          ),
          child: hasImage
              ? (_newBanner != null
                    ? Image.memory(
                        _newBanner!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined,
                              size: 32, color: Colors.grey),
                        ),
                      )
                    : Image.network(
                        profileImageUrl(_bannerImage),
                        fit: BoxFit.cover,
                        cacheWidth: 800,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined,
                              size: 32, color: Colors.grey),
                        ),
                      ))
              : const Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 32,
                    color: Colors.grey,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickBanner,
                icon: const Icon(Icons.upload_outlined, size: 18, color: kAuthPrimary),
                label: Text(
                  hasImage ? "Ganti Banner" : "Upload Banner",
                  style: const TextStyle(color: kAuthPrimary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kAuthPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _newBanner = null;
                  _bannerImage = null;
                  _bannerCleared = true;
                }),
                icon: const Icon(Icons.close, size: 18, color: Color(0xFFC0392B)),
                label: const Text(
                  "Hapus",
                  style: TextStyle(color: Color(0xFFC0392B)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFC0392B)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Icon(Icons.tune, size: 18, color: kAuthPrimary),
              const SizedBox(width: 8),
              const Text(
                "Pengaturan",
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
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _formTypeId,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 1, child: Text("Single Page")),
                DropdownMenuItem(value: 2, child: Text("Multi Page")),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _formTypeId = v);
              },
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _customLinkController,
            decoration: _fieldDecoration(
              "Link kustom (mis. survey-kepuasan, opsional)",
            ),
            onChanged: (v) => _customLinkController.value =
                _customLinkController.value.copyWith(
              text: _sanitizeLink(v),
              selection: TextSelection.collapsed(
                offset: _sanitizeLink(v).length,
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _timerController,
            keyboardType: TextInputType.number,
            decoration: _fieldDecoration(
              "Batas waktu pengerjaan (menit, opsional)",
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenController,
            decoration: _fieldDecoration(
              "Token akses form (opsional)",
            ),
          ),
          const SizedBox(height: 8),
          _buildDateTimeTile(
            icon: Icons.lock_open_outlined,
            title: "Waktu buka form",
            subtitle: _openTimeAlreadySet
                ? "Sudah diatur, tidak bisa diubah"
                : "Form terbuka otomatis di waktu ini",
            value: _openFormTime,
            enabled: !_openTimeAlreadySet,
            onTap: _openTimeAlreadySet ? null : () => _pickOpenTime(),
          ),
          const SizedBox(height: 8),
          _buildDateTimeTile(
            icon: Icons.lock_outline,
            title: "Waktu tutup form",
            subtitle: "Form berhenti menerima respons",
            value: _closeFormTime,
            enabled: true,
            onTap: () => _pickCloseTime(),
          ),
          const SizedBox(height: 8),
          _buildSwitch(
            "Tampilkan skor",
            "Responden melihat nilai setelah submit",
            _showScore,
            (v) => setState(() => _showScore = v),
          ),
          _buildSwitch(
            "Acak pertanyaan",
            "Urutan pertanyaan diacak",
            _randomizeQuestions,
            (v) => setState(() => _randomizeQuestions = v),
          ),
          _buildSwitch(
            "Satu respons per orang",
            "Batasi tiap orang hanya 1 kali isi",
            _oneResponse,
            (v) => setState(() => _oneResponse = v),
          ),
          _buildSwitch(
            "Wajib login",
            "Responden harus login untuk mengerjakan",
            _requiredLogin,
            (v) => setState(() => _requiredLogin = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: Colors.black54),
      ),
      value: value,
      activeTrackColor: kAuthPrimary,
      onChanged: onChanged,
    );
  }

  Widget _buildDateTimeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required DateTime? value,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? const Color(0xFF6E7979) : const Color(0xFFD8DEDE),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled ? kAuthPrimary : Colors.grey.shade400,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value == null
                        ? (enabled ? subtitle : "Belum diatur")
                        : _formatDateTime(value),
                    style: TextStyle(
                      fontSize: 12,
                      color: value != null
                          ? kAuthPrimary
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey)
            else
              const Icon(
                Icons.lock,
                size: 16,
                color: Colors.grey,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickOpenTime() async {
    final picked = await _pickDateTime(_openFormTime);
    if (picked != null) setState(() => _openFormTime = picked);
  }

  Future<void> _pickCloseTime() async {
    final picked = await _pickDateTime(_closeFormTime);
    if (picked != null) setState(() => _closeFormTime = picked);
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return null;
    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickBanner() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFBDC9C8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _imageSourceTile(
              icon: Icons.photo_library_outlined,
              label: 'Pilih dari Galeri',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            _imageSourceTile(
              icon: Icons.photo_camera_outlined,
              label: 'Ambil Foto',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _newBanner = bytes);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  Widget _imageSourceTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: kPrimarySoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBDC9C8)),
        ),
        child: Row(
          children: [
            Icon(icon, color: kAuthPrimary, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  String _sanitizeLink(String value) {
    final v = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
    return v.length > 100 ? v.substring(0, 100) : v;
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return "${local.day} ${months[local.month - 1]} ${local.year}, $hh:$mm";
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kAuthText, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF0F4F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kAuthText),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF6E7979)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kAuthPrimary, width: 1.5),
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
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
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: q.typeId,
                    isExpanded: true,
                    items: [
                      for (final e in _types.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            e.value.$1,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        q.typeId = v;
                        if (!q.hasOptions) {
                          for (final o in q.options) {
                            o.text.dispose();
                          }
                          q.options.clear();
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  _previewQuestion == index
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: _previewQuestion == index
                      ? kAuthPrimary
                      : Colors.grey,
                ),
                tooltip: "Pratinjau soal",
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() {
                  _previewQuestion =
                      _previewQuestion == index ? null : index;
                }),
              ),
              if (index > 0)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_upward,
                    size: 18,
                    color: Colors.grey,
                  ),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
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
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
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
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() {
                  q.dispose();
                  _questions.removeAt(index);
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichTextEditor(
            controller: q.question,
            hint: "Tulis pertanyaan...",
            minHeight: 70,
          ),
          if (_previewQuestion == index) ...[
            const SizedBox(height: 12),
            _buildQuestionPreview(q),
          ],
          if (q.typeId == 5) ...[
            const SizedBox(height: 12),
            _buildTrueFalseAnswer(q),
          ],
          if (q.typeId == 1) ...[
            const SizedBox(height: 12),
            TextField(
              controller: q.correctAnswer,
              maxLines: null,
              decoration: _fieldDecoration(
                "Kunci jawaban (opsional, untuk kuis)",
              ),
            ),
          ],
          if (q.hasOptions) ...[
            const SizedBox(height: 12),
            for (var oi = 0; oi < q.options.length; oi++)
              _buildOptionRow(q, oi),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => q.options.add(_OptionDraft())),
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: kAuthPrimary,
                ),
                label: const Text(
                  "Tambahkan opsi",
                  style: TextStyle(color: kAuthPrimary),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _buildQuestionMedia(q, index),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                "Wajib dijawab",
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const Spacer(),
              Switch(
                value: q.isRequired,
                activeTrackColor: kAuthPrimary,
                onChanged: (v) => setState(() => q.isRequired = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Media soal (gambar + audio): upload hanya bisa setelah soal tersimpan
  /// (butuh question id di server).
  Widget _buildQuestionMedia(_QuestionDraft q, int index) {
    final needsSave = q.id == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (q.questionImage != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              profileImageUrl(q.questionImage),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: 800,
              errorBuilder: (_, _, _) => Container(
                height: 120,
                alignment: Alignment.center,
                color: const Color(0xFFF0F4F4),
                child: const Icon(Icons.broken_image_outlined,
                    size: 32, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (q.questionAudio != null) ...[
          Row(
            children: [
              const Icon(Icons.audio_file, size: 18, color: kAuthPrimary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Audio terlampir',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                onPressed: () => setState(() => q.questionAudio = null),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        if (needsSave)
          const Text(
            'Simpan form dulu untuk upload gambar/audio soal.',
            style: TextStyle(fontSize: 11, color: Colors.black45, fontStyle: FontStyle.italic),
          )
        else if (_uploadingQuestion == index)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (q.questionImage != null)
                TextButton.icon(
                  onPressed: () => setState(() => q.questionImage = null),
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFFC0392B)),
                  label: const Text(
                    'Hapus Gambar',
                    style: TextStyle(fontSize: 12, color: Color(0xFFC0392B)),
                  ),
                ),
              if (q.questionAudio != null)
                TextButton.icon(
                  onPressed: () => setState(() => q.questionAudio = null),
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFFC0392B)),
                  label: const Text(
                    'Hapus Audio',
                    style: TextStyle(fontSize: 12, color: Color(0xFFC0392B)),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _pickQuestionImage(q, index),
                icon: const Icon(Icons.image_outlined, size: 16, color: kAuthPrimary),
                label: Text(
                  q.questionImage != null ? 'Ganti Gambar' : 'Tambah Gambar',
                  style: const TextStyle(fontSize: 12, color: kAuthPrimary),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickQuestionAudio(q, index),
                icon: const Icon(Icons.audio_file_outlined, size: 16, color: kAuthPrimary),
                label: Text(
                  q.questionAudio != null ? 'Ganti Audio' : 'Tambah Audio',
                  style: const TextStyle(fontSize: 12, color: kAuthPrimary),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _pickQuestionImage(_QuestionDraft q, int index) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFBDC9C8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _imageSourceTile(
              icon: Icons.photo_library_outlined,
              label: 'Pilih dari Galeri',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            _imageSourceTile(
              icon: Icons.photo_camera_outlined,
              label: 'Ambil Foto',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
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
      setState(() => _uploadingQuestion = index);
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
        if (mounted) setState(() => _uploadingQuestion = null);
      }
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  Future<void> _pickQuestionAudio(_QuestionDraft q, int index) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      if (file == null || file.bytes == null) return;
      if (!mounted) return;
      setState(() => _uploadingQuestion = index);
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
        if (mounted) setState(() => _uploadingQuestion = null);
      }
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  /// Panel pratinjau satu soal: tampilkan pertanyaan + tipe jawaban seolah
  /// dilihat responden.
  Widget _buildQuestionPreview(_QuestionDraft q) {
    final previewText = q.question.document.toPlainText().trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBDC9C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 14, color: kAuthPrimary),
              const SizedBox(width: 4),
              const Text(
                "Pratinjau Soal",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: kAuthPrimary,
                ),
              ),
              const Spacer(),
              Text(
                _types[q.typeId]?.$1 ?? '',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (previewText.isEmpty)
            const Text(
              'Belum ada teks pertanyaan.',
              style: TextStyle(fontSize: 12, color: Colors.black45, fontStyle: FontStyle.italic),
            )
          else
            RichTextView(
              text: encodeRichText(q.question),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          const SizedBox(height: 8),
          if (q.typeId == 2)
            for (final o in q.options)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.radio_button_unchecked, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichTextView(
                        text: encodeRichText(o.text),
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              )
          else if (q.typeId == 3)
            for (final o in q.options)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.check_box_outline_blank, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichTextView(
                        text: encodeRichText(o.text),
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              )
          else if (q.typeId == 5)
            Row(
              children: [
                _previewChip('Benar'),
                const SizedBox(width: 8),
                _previewChip('Salah'),
              ],
            )
          else if (q.typeId == 4)
            const Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  'Pilih tanggal & waktu',
                  style: TextStyle(fontSize: 13, color: Colors.black45),
                ),
              ],
            )
          else
            Text(
              q.typeId == 1 ? 'Jawaban esai (teks panjang)' : '',
              style: const TextStyle(fontSize: 13, color: Colors.black45),
            ),
        ],
      ),
    );
  }

  Widget _previewChip(String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF6E7979)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
      ),
    );
  }

  /// Kartu berbagi: URL publik + QR code. Memuat on-demand saat build.
  Widget _buildShareCard() {
    if (_shareInfo == null && !_shareLoading && _shareQr == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadShareInfo());
    }
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Icon(Icons.share_outlined, size: 18, color: kAuthPrimary),
              const SizedBox(width: 8),
              const Text(
                "Bagikan Form",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_shareLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_shareInfo == null && _shareQr == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Gagal memuat info berbagi.',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _shareInfo?['shareUrl'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18, color: kAuthPrimary),
                  tooltip: "Salin link",
                  onPressed: () {
                    final url = _shareInfo?['shareUrl'] as String? ?? '';
                    Clipboard.setData(ClipboardData(text: url));
                    showAuthToast(context, 'Link disalin');
                  },
                ),
              ],
            ),
            if (_shareInfo?['requiresToken'] == true) ...[
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.lock_outline, size: 14, color: Color(0xFFB26A00)),
                  SizedBox(width: 6),
                  Text(
                    'Form ini dilindungi token akses.',
                    style: TextStyle(fontSize: 11, color: Color(0xFFB26A00)),
                  ),
                ],
              ),
            ],
            if (_shareQr != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBDC9C8)),
                  ),
                  child: Image.memory(
                    _shareQr!,
                    width: 160,
                    height: 160,
                    errorBuilder: (_, _, _) => Container(
                      width: 160,
                      height: 160,
                      color: const Color(0xFFF0F4F4),
                      child: const Icon(
                        Icons.qr_code_2,
                        color: Colors.grey,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Scan QR untuk membuka form',
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _loadShareInfo() async {
    if (_shareLoading) return;
    setState(() => _shareLoading = true);
    try {
      final info = await FormService.getShareInfo(widget.formId!);
      Uint8List? qr;
      try {
        qr = await FormService.getShareQr(widget.formId!);
      } catch (_) {
        qr = null; // QR gagal dimuat — tetap tampilkan link.
      }
      if (!mounted) return;
      setState(() {
        _shareInfo = info;
        _shareQr = qr;
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _shareLoading = false);
    }
  }

  Widget _buildTrueFalseAnswer(_QuestionDraft q) {
    return Row(
      children: [
        Expanded(
          child: _answerChip(
            "Benar",
            q.correctAnswer.text == 'Benar',
            () => setState(() => q.correctAnswer.text = 'Benar'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _answerChip(
            "Salah",
            q.correctAnswer.text == 'Salah',
            () => setState(() => q.correctAnswer.text = 'Salah'),
          ),
        ),
      ],
    );
  }

  Widget _answerChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kPrimarySoft : const Color(0xFFF0F4F4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? kAuthPrimary : const Color(0xFF6E7979),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: selected ? kAuthPrimary : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow(_QuestionDraft q, int oi) {
    final o = q.options[oi];
    final singleSelect = q.typeId == 2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (singleSelect) {
                  for (final opt in q.options) {
                    opt.isCorrect = false;
                  }
                  o.isCorrect = true;
                } else {
                  o.isCorrect = !o.isCorrect;
                }
              });
            },
            child: Icon(
              singleSelect
                  ? (o.isCorrect
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked)
                  : (o.isCorrect
                        ? Icons.check_box
                        : Icons.check_box_outline_blank),
              color: o.isCorrect ? kAuthPrimary : const Color(0xFF6E7979),
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichTextEditor(
              controller: o.text,
              hint: "Opsi ${oi + 1}",
              minHeight: 40,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: () {
              setState(() {
                o.text.dispose();
                q.options.removeAt(oi);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddQuestionButton() {
    return OutlinedButton.icon(
      onPressed: _pickQuestionType,
      icon: const Icon(Icons.add, color: kAuthPrimary),
      label: const Text(
        "Tambah Pertanyaan",
        style: TextStyle(color: kAuthPrimary),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: kAuthPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
