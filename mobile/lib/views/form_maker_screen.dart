import 'package:flutter/material.dart';
import 'auth/widgets/auth_widgets.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';

class _OptionDraft {
  final TextEditingController text = TextEditingController();
  bool isCorrect = false;
}

class _QuestionDraft {
  int typeId;
  final TextEditingController question = TextEditingController();
  bool isRequired = true;
  final List<_OptionDraft> options = [];

  _QuestionDraft(this.typeId);

  bool get hasOptions =>
      typeId == 1 || typeId == 2 || typeId == 5; // mc, checkbox, dropdown
}

/// Tipe pertanyaan (ID dari tabel referensi QuestionType).
const _types = {
  1: ('Pilihan Ganda', Icons.radio_button_checked),
  2: ('Checkbox', Icons.check_box_outlined),
  3: ('Jawaban Singkat', Icons.short_text),
  4: ('Paragraf', Icons.notes),
  5: ('Dropdown', Icons.arrow_drop_down_circle_outlined),
  6: ('Rating', Icons.star_outline),
  7: ('Tanggal', Icons.calendar_today_outlined),
  8: ('Waktu', Icons.access_time),
  9: ('Upload File', Icons.attach_file),
  10: ('Skala Linear', Icons.linear_scale),
};

class FormMakerScreen extends StatefulWidget {
  const FormMakerScreen({super.key});

  @override
  State<FormMakerScreen> createState() => _FormMakerScreenState();
}

class _FormMakerScreenState extends State<FormMakerScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final List<_QuestionDraft> _questions = [];
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    for (final q in _questions) {
      q.question.dispose();
      for (final o in q.options) {
        o.text.dispose();
      }
    }
    super.dispose();
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in _types.entries)
                  GestureDetector(
                    onTap: () => Navigator.pop(context, entry.key),
                    child: Container(
                      width: (MediaQuery.of(context).size.width - 50) / 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1F9F4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBDC9C8)),
                      ),
                      child: Row(
                        children: [
                          Icon(entry.value.$2, color: kAuthPrimary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value.$1,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
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
      if (q.hasOptions && q.options.isEmpty) {
        showAuthToast(
          context,
          "Tambahkan opsi pada pertanyaan pilihan",
          isError: true,
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final formId = await FormService.createForm(
        title: title,
        description: _descController.text.trim(),
      );
      await FormService.saveQuestions(formId, [
        for (final q in _questions)
          {
            'typeId': q.typeId,
            'question': q.question.text.trim(),
            'isRequired': q.isRequired,
            if (q.hasOptions)
              'options': [
                for (final o in q.options)
                  {'optionText': o.text.text.trim(), 'isCorrect': o.isCorrect},
              ],
          },
      ]);
      if (!mounted) return;
      Navigator.pop(context, formId);
      showAuthToast(context, "Form berhasil dibuat");
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
        title: const Text(
          "Buat Form",
          style: TextStyle(fontFamily: kFontBold, color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFormHeader(),
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
                  color: Color(0xFFE1F9F4),
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
                        if (!q.hasOptions) q.options.clear();
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
                  q.question.dispose();
                  for (final o in q.options) {
                    o.text.dispose();
                  }
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

  Widget _buildOptionRow(_QuestionDraft q, int oi) {
    final o = q.options[oi];
    final singleSelect = q.typeId == 1 || q.typeId == 5;
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
