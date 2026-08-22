import 'package:flutter/material.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Kartu expandable satu responden beserta rincian jawabannya
class AnalyticsRespondentCard extends StatelessWidget {
  final int index;
  final RespondentAnalyticsData respondent;

  const AnalyticsRespondentCard({
    super.key,
    required this.index,
    required this.respondent,
  });

  @override
  Widget build(BuildContext context) {
    final r = respondent;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: ExpansionTile(
        shape: const Border(),
        leading: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: kPrimarySoft,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: kAuthPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ),
        title: Text(
          (r.respondentName ?? '').trim().isEmpty
              ? 'Responden ${index + 1}'
              : r.respondentName!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          "${r.answeredCount}/${r.totalQuestions} dijawab · ${_formatTime(r.submittedAt)}",
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        trailing: _ScoreChip(r.score),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (var i = 0; i < r.answers.length; i++) _AnswerRow(i, r.answers[i]),
        ],
      ),
    );
  }
}

/// Satu baris jawaban pada rincian responden
class _AnswerRow extends StatelessWidget {
  final int index;
  final AnswerAnalyticsData answer;

  const _AnswerRow(this.index, this.answer);

  @override
  Widget build(BuildContext context) {
    final a = answer;
    final answered = a.answerText != null && a.answerText!.isNotEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichTextView(
                  text: a.question,
                  prefix: '${index + 1}. ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (a.isCorrect != null)
                Icon(
                  a.isCorrect! ? Icons.check_circle : Icons.cancel,
                  color: a.isCorrect!
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC0392B),
                  size: 18,
                ),
            ],
          ),
          const SizedBox(height: 4),
          RichTextView(
            text: answered ? a.answerText! : 'Tidak dijawab',
            style: TextStyle(
              fontSize: 12,
              color: answered ? Colors.black87 : Colors.black45,
              fontStyle: answered ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          if (a.correctAnswer != null &&
              a.correctAnswer!.isNotEmpty &&
              a.correctAnswer != a.answerText) ...[
            const SizedBox(height: 4),
            RichTextView(
              text: 'Jawaban benar: ${a.correctAnswer}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip skor responden dengan warna sesuai nilai
class _ScoreChip extends StatelessWidget {
  final double? score;

  const _ScoreChip(this.score);

  @override
  Widget build(BuildContext context) {
    if (score == null) {
      return const Text(
        '—',
        style: TextStyle(fontSize: 13, color: Colors.black45),
      );
    }
    final color = score! >= 75
        ? const Color(0xFF2E7D32)
        : score! >= 50
            ? const Color(0xFFB26A00)
            : const Color(0xFFC0392B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${score!.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          color: color,
        ),
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return "${local.day}/${local.month}/${local.year} $hh:$mm";
}
