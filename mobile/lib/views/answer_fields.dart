import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'rich_editor.dart';

/// Opsi jawaban sederhana (id + teks) untuk [AnswerFields].
class AnswerOption {
  final int id;
  final String text;
  const AnswerOption(this.id, this.text);
}

/// Render input jawaban satu pertanyaan (Essay, Pilihan Ganda, Checkbox,
/// Tanggal & Waktu, Benar/Salah). Dipakai bersama oleh alur mengerjakan form
/// dan mode pratinjau form.
class AnswerFields extends StatelessWidget {
  final int typeId;
  final List<AnswerOption> options;
  final TextEditingController? essayController;
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
          maxLines: 3,
          onChanged: onEssayChanged,
          decoration: _decoration("Tulis jawaban Anda..."),
        );
      case 2: // Multiple Choice
        return RadioGroup<int>(
          groupValue: singleValue,
          onChanged: onSingleChanged ?? (_) {},
          child: Column(
            children: [
              for (final o in options)
                RadioListTile<int>(
                  value: o.id,
                  title: RichTextView(
                    text: o.text,
                    style: const TextStyle(fontSize: 14),
                  ),
                  dense: true,
                  activeColor: kAuthPrimary,
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        );
      case 3: // Checkbox
        return Column(
          children: [
            for (final o in options)
              CheckboxListTile(
                value: multiValue.contains(o.id),
                onChanged: onMultiChanged == null
                    ? null
                    : (v) {
                        final selected = Set<int>.of(multiValue);
                        if (v == true) {
                          selected.add(o.id);
                        } else {
                          selected.remove(o.id);
                        }
                        onMultiChanged!(selected);
                      },
                title: RichTextView(
                  text: o.text,
                  style: const TextStyle(fontSize: 14),
                ),
                dense: true,
                activeColor: kAuthPrimary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
          ],
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
}
