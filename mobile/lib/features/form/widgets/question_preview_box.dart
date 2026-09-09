import 'package:flutter/material.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Kotak pratinjau soal (teks + opsi/chip jawaban)
class QuestionPreviewBox extends StatelessWidget {
  final QuestionDraft draft;

  const QuestionPreviewBox({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = draft;
    final previewText = q.question.document.toPlainText().trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 14, color: cs.primary),
              const SizedBox(width: 4),
              Text(
                "Pratinjau Soal",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              const Spacer(),
              Text(
                questionTypes[q.typeId]?.$1 ?? '',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (previewText.isEmpty)
            Text(
              'Belum ada teks pertanyaan.',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            RichTextView(
              text: encodeRichText(q.question),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          const SizedBox(height: 8),
          if (q.typeId == 2)
            for (final o in q.options)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      Icons.radio_button_unchecked,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichTextView(
                        text: encodeRichText(o.text),
                        style: TextStyle(fontSize: 13, color: cs.onSurface),
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
                    Icon(
                      Icons.check_box_outline_blank,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichTextView(
                        text: encodeRichText(o.text),
                        style: TextStyle(fontSize: 13, color: cs.onSurface),
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
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Pilih tanggal & waktu',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            )
          else
            Text(
              q.typeId == 1 ? 'Jawaban esai (teks panjang)' : '',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
      ),
    );
  }
}
