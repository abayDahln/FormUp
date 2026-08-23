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
          children: const [
            Text(
              "Pertanyaan",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: kAuthPrimary,
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
            const Text(
              "Pratinjau",
              style: TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Switch(
              value: preview,
              activeTrackColor: kAuthPrimary,
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
