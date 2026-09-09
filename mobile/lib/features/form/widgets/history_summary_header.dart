import 'package:flutter/material.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Kartu ringkasan hasil: judul form + baris skor (bila ditampilkan)
class HistorySummaryHeader extends StatelessWidget {
  final PublicFormResult result;

  const HistorySummaryHeader({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Form",
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          RichTextView(
            text: result.formTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: cs.onSurface,
            ),
          ),
          if (result.showScore) ...[
            const SizedBox(height: 16),
            _HistoryScoreRow(result: result),
          ],
        ],
      ),
    );
  }
}

/// Baris statistik skor: Skor / Benar / Salah
class _HistoryScoreRow extends StatelessWidget {
  final PublicFormResult result;

  const _HistoryScoreRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = result.score;
    final color = score == null
        ? Colors.grey
        : (score >= 75
            ? const Color(0xFF2E7D32)
            : score >= 50
                ? const Color(0xFFB26A00)
                : const Color(0xFFC0392B));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ScoreStat(
            score == null ? "—" : "${score.toStringAsFixed(1)}%",
            "Skor",
            color,
          ),
          _ScoreStat(
            "${result.correctCount}",
            "Benar",
            const Color(0xFF2E7D32),
          ),
          _ScoreStat(
            "${result.wrongCount}",
            "Salah",
            const Color(0xFFC0392B),
          ),
        ],
      ),
    );
  }
}

/// Satu sel statistik skor
class _ScoreStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _ScoreStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
