import 'package:flutter/material.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Isi section "Jawaban": benar/salah, esai, atau daftar opsi
class QuestionAnswerSection extends StatelessWidget {
  final QuestionDraft draft;
  final VoidCallback onChanged;
  final Key? optionsKey;

  const QuestionAnswerSection({
    super.key,
    required this.draft,
    required this.onChanged,
    this.optionsKey,
  });

  @override
  Widget build(BuildContext context) {
    final q = draft;
    if (q.typeId == 5) return _buildTrueFalseAnswer(q);
    if (q.typeId == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kunci Jawaban',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: kAuthPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: q.correctAnswer,
            maxLines: null,
            decoration: _fieldDecoration(
              "Kunci jawaban untuk kuis",
            ),
          ),
        ],
      );
    }
    if (q.hasOptions) {
      return Column(
        key: optionsKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Text(
                'Opsi Jawaban',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: kAuthPrimary,
                ),
              ),
              SizedBox(width: 2),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: kDangerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var oi = 0; oi < q.options.length; oi++)
            _OptionRow(
              index: oi,
              draft: q,
              onChanged: onChanged,
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                q.options.add(OptionDraft());
                onChanged();
              },
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
      );
    }
    return const Text(
      'Jawaban tanggal & waktu diisi responden langsung.',
      style: TextStyle(fontSize: 12, color: Colors.black45),
    );
  }
}

Widget _buildTrueFalseAnswer(QuestionDraft q) {
  return Row(
    children: [
      Expanded(
        child: _AnswerChip(
          "Benar",
          q.correctAnswer.text == 'Benar',
          () {
            q.correctAnswer.text = 'Benar';
          },
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _AnswerChip(
          "Salah",
          q.correctAnswer.text == 'Salah',
          () {
            q.correctAnswer.text = 'Salah';
          },
        ),
      ),
    ],
  );
}

/// Chip pilihan jawaban benar/salah
class _AnswerChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AnswerChip(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
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
}

/// Satu baris opsi jawaban (radio/checkbox + editor + hapus)
class _OptionRow extends StatelessWidget {
  final int index;
  final QuestionDraft draft;
  final VoidCallback onChanged;

  const _OptionRow({
    required this.index,
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final q = draft;
    final o = q.options[index];
    final singleSelect = q.typeId == 2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              if (singleSelect) {
                for (final opt in q.options) {
                  opt.isCorrect = false;
                }
                o.isCorrect = true;
              } else {
                o.isCorrect = !o.isCorrect;
              }
              onChanged();
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
              hint: "Opsi ${index + 1}",
              minHeight: 40,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: () {
              o.text.dispose();
              q.options.removeAt(index);
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kAuthText, fontSize: 14),
    filled: true,
    fillColor: Colors.white,
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
