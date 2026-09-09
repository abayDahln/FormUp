import 'package:flutter/material.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/features/form/widgets/question_preview_box.dart';
import 'package:form_up/features/form/widgets/question_type_dropdown.dart';

/// Isi section "Soal": dropdown tipe, editor teks, switch pratinjau
class QuestionTextSection extends StatelessWidget {
  final QuestionDraft draft;
  final bool preview;
  final ValueChanged<bool> onPreviewChanged;
  final ValueChanged<int> onTypeChanged;

  const QuestionTextSection({
    super.key,
    required this.draft,
    required this.preview,
    required this.onPreviewChanged,
    required this.onTypeChanged,
    this.questionFieldKey,
  });

  final Key? questionFieldKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionTypeDropdown(
          typeId: q.typeId,
          onChanged: onTypeChanged,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              "Pertanyaan",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: cs.primary,
              ),
            ),
            SizedBox(width: 2),
            Text(
              "*",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: kDangerColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RichTextEditor(
          controller: q.question,
          hint: "Tulis pertanyaan...",
          minHeight: 70,
          key: questionFieldKey,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              "Pratinjau",
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            Switch(
              value: preview,
              activeTrackColor: cs.primary,
              onChanged: onPreviewChanged,
            ),
          ],
        ),
        if (preview) ...[
          const SizedBox(height: 8),
          QuestionPreviewBox(draft: q),
        ],
      ],
    );
  }
}
