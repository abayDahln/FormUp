import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

class AnswerOption {
  final int id;
  final String text;
  const AnswerOption(this.id, this.text);
}

/// Input jawaban per tipe soal
class AnswerFields extends StatelessWidget {
  final int typeId;
  final List<AnswerOption> options;
  final TextEditingController? essayController;
  final FocusNode? essayFocusNode;
  final ValueChanged<String>? onEssayChanged;
  final int? singleValue;
  final Set<int> multiValue;
  final String? tfValue;
  final String? dateLabel;
  final ValueChanged<int?>? onSingleChanged;
  final ValueChanged<Set<int>>? onMultiChanged;
  final ValueChanged<String?>? onTfChanged;
  final VoidCallback? onPickDateTime;

  const AnswerFields({
    super.key,
    required this.typeId,
    this.options = const [],
    this.essayController,
    this.essayFocusNode,
    this.onEssayChanged,
    this.singleValue,
    this.multiValue = const {},
    this.tfValue,
    this.dateLabel,
    this.onSingleChanged,
    this.onMultiChanged,
    this.onTfChanged,
    this.onPickDateTime,
  });

  @override
  Widget build(BuildContext context) {
    switch (typeId) {
      case 1: // Essay
        return TextField(
          controller: essayController,
          focusNode: essayFocusNode,
          maxLines: 3,
          onChanged: onEssayChanged,
          decoration: _decoration("Tulis jawaban Anda..."),
        );
      case 2: // Multiple Choice
        return Material(
          type: MaterialType.transparency,
          child: RadioGroup<int>(
            groupValue: singleValue,
            onChanged: onSingleChanged ?? (_) {},
            child: Column(
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE5E8E8),
                    ),
                  _buildChoiceOption(
                    index: i,
                    text: options[i].text,
                    onTap: onSingleChanged == null
                        ? null
                        : () => onSingleChanged!(options[i].id),
                    control: Radio<int>(
                      value: options[i].id,
                      activeColor: kAuthPrimary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      case 3: // Checkbox
        return Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE5E8E8),
                  ),
                _buildChoiceOption(
                  index: i,
                  text: options[i].text,
                  onTap: onMultiChanged == null
                      ? null
                      : () => _toggleMulti(options[i].id),
                  control: Checkbox(
                    value: multiValue.contains(options[i].id),
                    onChanged: onMultiChanged == null
                        ? null
                        : (_) => _toggleMulti(options[i].id),
                    activeColor: kAuthPrimary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ],
          ),
        );
      case 4: // Date Time
        return InkWell(
          onTap: onPickDateTime,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6E7979)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: kAuthPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dateLabel ?? "Pilih tanggal & waktu",
                    style: TextStyle(
                      fontSize: 14,
                      color: dateLabel == null ? Colors.black45 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case 5: // True/False
        return Row(
          children: [
            Expanded(
              child: _chip(
                "Benar",
                tfValue == 'Benar',
                onTfChanged == null ? null : () => onTfChanged!('Benar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _chip(
                "Salah",
                tfValue == 'Salah',
                onTfChanged == null ? null : () => onTfChanged!('Salah'),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _chip(String label, bool selected, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kPrimarySoft : const Color(0xFFF0F4F4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kAuthPrimary : const Color(0xFF6E7979),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: selected ? kAuthPrimary : Colors.black54,
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kAuthText, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF0F4F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF6E7979)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF6E7979)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kAuthPrimary, width: 1.5),
      ),
    );
  }

  void _toggleMulti(int optionId) {
    final selected = Set<int>.of(multiValue);
    if (selected.contains(optionId)) {
      selected.remove(optionId);
    } else {
      selected.add(optionId);
    }
    onMultiChanged!(selected);
  }

  /// Baris opsi pilihan ganda/checkbox:
  /// kontrol (radio/checkbox) + teks opsi format "A. {text}".
  Widget _buildChoiceOption({
    required int index,
    required String text,
    required Widget control,
    VoidCallback? onTap,
  }) {
    final letter = String.fromCharCode(65 + index);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            control,
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                '$letter. ',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: RichTextView(
                  text: text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultOptionsList extends StatelessWidget {
  final List<String> options;
  final String? answerText;
  final String? correctAnswer;
  final bool showScore;

  const ResultOptionsList({
    super.key,
    required this.options,
    this.answerText,
    this.correctAnswer,
    this.showScore = false,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _OptionResultRow(
              letter: String.fromCharCode(65 + i),
              option: options[i],
              isCorrect: showScore &&
                  correctAnswer != null &&
                  options[i] == correctAnswer,
              isUserAnswer: answerText != null && options[i] == answerText,
            ),
          ),
      ],
    );
  }
}

class _OptionResultRow extends StatelessWidget {
  final String letter;
  final String option;
  final bool isCorrect;
  final bool isUserAnswer;

  const _OptionResultRow({
    required this.letter,
    required this.option,
    required this.isCorrect,
    required this.isUserAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isCorrect
        ? const Color(0xFFE3F4E8)
        : isUserAnswer
            ? const Color(0xFFE0F2F1)
            : const Color(0xFFF0F4F4);
    final fg = isCorrect
        ? const Color(0xFF2E7D32)
        : isUserAnswer
            ? kAuthPrimary
            : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            letter,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: fg,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichTextView(
              text: option,
              style: TextStyle(fontSize: 13, color: fg),
            ),
          ),
          if (isCorrect)
            const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32))
          else if (isUserAnswer)
            Icon(Icons.radio_button_checked, size: 16, color: kAuthPrimary),
        ],
      ),
    );
  }
}

