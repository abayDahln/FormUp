import 'package:flutter/material.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Kartu satu responden pada analisis form — tap untuk buka detail jawaban
class AnalyticsRespondentCard extends StatelessWidget {
  final int index;
  final RespondentAnalyticsData respondent;
  final VoidCallback onTap;

  const AnalyticsRespondentCard({
    super.key,
    required this.index,
    required this.respondent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = respondent;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                    const SizedBox(height: 3),
                    Text(
                      "${r.answeredCount}/${r.totalQuestions} dijawab · ${_formatTime(r.submittedAt)}",
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              _ScoreChip(r.score),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
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
