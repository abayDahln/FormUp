import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Kartu preview SATU soal AI — dipakai bersama oleh preview final
/// (ActionJsonTabs) dan preview real-time streaming, agar UI-nya identik:
/// teks cukup besar, warna bersih (bukan abu buram), LaTeX ikut ter-render
/// via RichTextView (renderer yang sama dengan layar soal).
class AiQuestionPreviewCard extends StatelessWidget {
  final Map question;
  final int index;

  const AiQuestionPreviewCard({
    super.key,
    required this.question,
    required this.index,
  });

  static const typeNames = {
    1: 'Esai',
    2: 'Pilihan Ganda',
    3: 'Checkbox',
    4: 'Date Time',
    5: 'True / False',
  };

  static String clean(String? s) => (s ?? '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String typeLabel(dynamic typeId) {
    final id = typeId is int ? typeId : int.tryParse('$typeId');
    return typeNames[id] ?? 'Soal';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = question;
    final orderRaw = q['questionOrder'] ?? q['order'];
    final order = orderRaw is int
        ? orderRaw
        : int.tryParse('${orderRaw ?? ''}');
    final isRequired = q['isRequired'] == true;
    final points = q['points'];
    final options = q['options'] as List<dynamic>? ?? [];
    final correct = q['correctAnswer'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _chip(
                context,
                'Soal ${order ?? index + 1}',
                color: cs.primary,
                filled: true,
              ),
              _chip(context, typeLabel(q['typeId'])),
              if (isRequired) _chip(context, 'Wajib', color: Colors.orange),
              if (points != null) _chip(context, '$points poin'),
            ],
          ),
          const SizedBox(height: 8),
          // Render sama dengan screen edit/pratinjau/pengerjaan soal:
          // rich text + LaTeX ($...$, $$...$$, \(...\)) via flutter_math_fork.
          RichTextView(
            text: clean(q['question'] as String?),
            style: TextStyle(fontSize: 15, color: cs.onSurface, height: 1.45),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < options.length; i++)
              _optionRow(context, options[i], i),
          ],
          if (correct != null && '$correct'.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 5),
                Expanded(
                  child: RichTextView(
                    text: clean('$correct'),
                    style: TextStyle(
                        fontSize: 14, color: Colors.green.shade700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionRow(BuildContext context, dynamic o, int index) {
    final cs = Theme.of(context).colorScheme;
    String text;
    bool isCorrect = false;
    if (o is String) {
      text = o;
    } else if (o is Map) {
      text = '${o['optionText'] ?? ''}';
      isCorrect = o['isCorrect'] == true;
    } else {
      text = '$o';
    }
    final letter = String.fromCharCode(65 + index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$letter.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: kFontBold,
                color: isCorrect ? Colors.green : cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: RichTextView(
              text: clean(text),
              style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.4),
            ),
          ),
          if (isCorrect)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.check_circle, size: 15, color: Colors.green),
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label,
      {Color? color, bool filled = false}) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? c.withValues(alpha: 0.14) : cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled ? c.withValues(alpha: 0.4) : cs.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: kFontBold,
          color: filled ? c : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
