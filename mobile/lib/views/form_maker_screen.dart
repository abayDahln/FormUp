import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';
import '../app_router.dart';

class _OptionDraft {
  int? id;
  final TextEditingController text;
  bool isCorrect;

  _OptionDraft({this.id, String text = '', this.isCorrect = false})
      : text = TextEditingController(text: text);
}

class _QuestionDraft {
  int? id;
  int typeId;
  final TextEditingController question;
  final TextEditingController correctAnswer;
  bool isRequired;
  bool randomizeOptions;
  final List<_OptionDraft> options;

  _QuestionDraft(
    this.typeId, {
    this.id,
    String question = '',
    String correctAnswer = '',
    this.isRequired = true,
    this.randomizeOptions = false,
  })  : question = TextEditingController(text: question),
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
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _timerController = TextEditingController();
  final _tokenController = TextEditingController();
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
        _titleController.text = form['title'] as String? ?? '';
        _descController.text = form['description'] as String? ?? '';
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

        _questions.clear();
        for (final q in questions) {
          final draft = _QuestionDraft(
            q.typeId,
            id: q.id,
            question: q.question,
            correctAnswer: q.correctAnswer ?? '',
            isRequired: q.isRequired ?? true,
            randomizeOptions: q.randomizeOptions ?? false,
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
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showAuthToast(context, "Judul form wajib diisi", isError: true);
      return;
    }
    if (_questions.isEmpty) {
      showAuthToast(context, "Tambahkan minimal 1 pertanyaan", isError: true);
      return;
    }
    for (final q in _questions) {
      if (q.question.text.trim().isEmpty) {
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
          if (o.text.text.trim().isEmpty) {
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
          'question': q.question.text.trim(),
          'isRequired': q.isRequired,
          'randomizeOptions': q.randomizeOptions,
          if (q.correctAnswer.text.trim().isNotEmpty)
            'correctAnswer': q.correctAnswer.text.trim(),
          if (q.hasOptions)
            'options': [
              for (final o in q.options)
                {
                  'optionText': o.text.text.trim(),
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
      final int formId;
      if (_isEdit) {
        formId = widget.formId!;
        await FormService.updateForm(
          formId,
          title: title,
          description: _descController.text.trim(),
        );
        await FormService.updateQuestions(formId, questionsPayload);
      } else {
        formId = await FormService.createForm(
          title: title,
          description: _descController.text.trim(),
        );
        await FormService.saveQuestions(formId, questionsPayload);
      }
      await FormService.updateSettings(formId, settingsPayload);

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
          : AuthBackground(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
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
                      const SizedBox(height: 24),
                      AuthPrimaryButton(
                        label: _saving ? "Menyimpan..." : "Simpan Form",
                        loading: _saving,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
              ),
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
          TextField(
            controller: _titleController,
            maxLines: null,
            decoration: _fieldDecoration("Contoh: Survey Kepuasan"),
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
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: _fieldDecoration(
              "Jelaskan tujuan form Anda (opsional)",
            ),
          ),
        ],
      ),
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
              if (index > 0)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_upward,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onPressed: () => _moveQuestion(index, -1),
                ),
              if (index < _questions.length - 1)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_downward,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onPressed: () => _moveQuestion(index, 1),
                ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Color(0xFFC0392B),
                ),
                onPressed: () => setState(() {
                  q.dispose();
                  _questions.removeAt(index);
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: q.question,
            maxLines: null,
            decoration: _fieldDecoration("Tulis pertanyaan..."),
          ),
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
            child: TextField(
              controller: o.text,
              decoration: _fieldDecoration("Opsi ${oi + 1}"),
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
