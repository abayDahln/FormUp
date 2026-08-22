import 'package:flutter/material.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Kotak pratinjau soal (teks + opsi/chip jawaban)
class QuestionPreviewBox extends StatelessWidget {
  final QuestionDraft draft;

  const QuestionPreviewBox({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    final q = draft;
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
                questionTypes[q.typeId]?.$1 ?? '',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (previewText.isEmpty)
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          const SizedBox(height: 8),
          if (q.typeId == 2)
            for (final o in q.options)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.radio_button_unchecked,
                      size: 16,
                      color: Colors.grey,
                    ),
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
                    const Icon(
                      Icons.check_box_outline_blank,
                      size: 16,
                      color: Colors.grey,
                    ),
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
            const Row(
              children: [
                Expanded(child: _PreviewChip('Benar')),
                SizedBox(width: 8),
                Expanded(child: _PreviewChip('Salah')),
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
}

/// Chip statis pada pratinjau benar/salah
class _PreviewChip extends StatelessWidget {
  final String label;

  const _PreviewChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6E7979)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: Colors.black54),
      ),
    );
  }
}
