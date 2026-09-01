import 'package:flutter/material.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Kartu satu soal pada daftar kelola soal
class QuestionListCard extends StatelessWidget {
  final int index;
  final int totalCount;
  final QuestionDraft question;
  final VoidCallback onEdit;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final double zoom;

  const QuestionListCard({
    super.key,
    required this.index,
    required this.totalCount,
    required this.question,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    this.zoom = 1.0,
  });
  double _zs(double v) => (v * zoom).clamp(10, 48).toDouble();

  @override
  Widget build(BuildContext context) {
    final q = question;
    final plainText = q.question.document.toPlainText().trim();
    final typeLabel = questionTypes[q.typeId]?.$1 ?? '';

    return GestureDetector(
      onTap: onEdit,
      child: Container(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plainText.isEmpty ? 'Belum ada teks pertanyaan.' : plainText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _zs(13),
                          fontWeight: FontWeight.w700,
                          fontFamily: kFontBold,
                          color: Colors.black87,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: _zs(11),
                          color: kAuthPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                MenuAnchor(
                  builder: (context, controller, child) => IconButton(
                    icon: const Icon(Icons.more_vert, size: 20, color: Colors.black54),
                    tooltip: 'Opsi soal',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                  ),
                  menuChildren: [
                    MenuItemButton(
                      leadingIcon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: onEdit,
                      child: const Text('Edit Soal'),
                    ),
                    MenuItemButton(
                      leadingIcon: const Icon(Icons.arrow_upward, size: 18),
                      onPressed: index > 0 ? onMoveUp : null,
                      child: const Text('Pindah ke atas'),
                    ),
                    MenuItemButton(
                      leadingIcon: const Icon(Icons.arrow_downward, size: 18),
                      onPressed: index < totalCount - 1 ? onMoveDown : null,
                      child: const Text('Pindah ke bawah'),
                    ),
                    const Divider(height: 1),
                    MenuItemButton(
                      leadingIcon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFC0392B)),
                      onPressed: onDelete,
                      child: const Text('Hapus', style: TextStyle(color: Color(0xFFC0392B))),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
