import 'package:flutter/material.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Kartu satu soal pada daftar kelola soal
class QuestionListCard extends StatelessWidget {
  final int index;
  final int totalCount;
  final QuestionDraft question;
  final VoidCallback onEdit;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  const QuestionListCard({
    super.key,
    required this.index,
    required this.totalCount,
    required this.question,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    final plainText = q.question.document.toPlainText().trim();
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
                child: Text(
                  questionTypes[q.typeId]?.$1 ?? '',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: kAuthPrimary,
                ),
                tooltip: "Edit soal",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
              ),
              if (index > 0)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_upward,
                    size: 18,
                    color: Colors.grey,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                  onPressed: onMoveUp,
                ),
              if (index < totalCount - 1)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_downward,
                    size: 18,
                    color: Colors.grey,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                  onPressed: onMoveDown,
                ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Color(0xFFC0392B),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (plainText.isEmpty)
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
        ],
      ),
    );
  }
}
