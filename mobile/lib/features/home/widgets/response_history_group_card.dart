import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/services/form_service.dart';

/// Satu form pada tab riwayat beserta semua attempt pengerjaannya
class ResponseHistoryGroup {
  final int formId;
  final String formTitle;
  final String formLink;
  final List<MyResponseItem> attempts = [];

  ResponseHistoryGroup(this.formId, this.formTitle, this.formLink);

  MyResponseItem get latest {
    var best = attempts.first;
    for (final a in attempts.skip(1)) {
      if ((a.submittedAt?.isAfter(best.submittedAt ??
              DateTime.fromMillisecondsSinceEpoch(0)) ??
          false)) {
        best = a;
      }
    }
    return best;
  }
}

/// Kartu riwayat tergabung per form (satu kartu = satu form)
class ResponseHistoryGroupCard extends StatelessWidget {
  final ResponseHistoryGroup group;
  final VoidCallback onTap;

  const ResponseHistoryGroupCard({
    super.key,
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadius),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: kPrimarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: kAuthPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichTextView(
                          text: group.formTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: kFontBold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Kode: ${group.formLink}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.grey, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(group.latest.submittedAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2F3F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${group.attempts.length}x dikerjakan',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: kAuthPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTime(DateTime? dt) {
  if (dt == null) return 'Waktu tidak diketahui';
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
