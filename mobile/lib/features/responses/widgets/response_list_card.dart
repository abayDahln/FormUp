import 'package:flutter/material.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/responses/widgets/response_status.dart';

/// Kartu satu grup responden (group by user) pada tab Respon.
/// Menampilkan 1 baris per user + jumlah pengerjaan; detail attempt
/// dilihat lewat [onOpenDetail] (screen detail sudah punya pemilih attempt).
class RespondentGroupCard extends StatelessWidget {
  final String displayName;
  final List<ResponseListItemData> attempts;
  final int index;
  final VoidCallback onOpenDetail;

  const RespondentGroupCard({
    super.key,
    required this.displayName,
    required this.attempts,
    required this.index,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = [...attempts]
      ..sort((a, b) {
        final da = a.submittedAt;
        final db = b.submittedAt;
        if (da == null && db == null) return b.id.compareTo(a.id);
        if (da == null) return 1;
        if (db == null) return -1;
        final c = db.compareTo(da);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    final latest = sorted.first;
    final style = responseStatusStyle(latest.status);
    final name = displayName.trim().isEmpty
        ? 'Responden ${index + 1}'
        : displayName.trim();
    final count = sorted.length;
    final subtitle = latest.submittedAt == null
        ? (count > 1 ? '${count}x pengerjaan' : 'Waktu tidak diketahui')
        : '${_formatTime(latest.submittedAt!)}'
            '${count > 1 ? ' • ${count}x pengerjaan' : ''}';
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          shape: const Border(),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: cs.primary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (count > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${count}x',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (count > 1)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < sorted.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == sorted.length - 1 ? 0 : 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.history,
                              size: 14,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Pengerjaan ${i + 1} • ${sorted[sorted.length - 1 - i].submittedAt == null ? 'waktu tidak diketahui' : _formatTime(sorted[sorted.length - 1 - i].submittedAt!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: style.$2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      style.$1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: style.$3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: onOpenDetail,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      count > 1 ? 'Lihat Semua ($count)' : 'Lihat Jawaban',
                      style: TextStyle(color: cs.primary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu expandable satu respons pada daftar respons form
class ResponseListCard extends StatelessWidget {
  final ResponseListItemData response;
  final int index;
  final VoidCallback onOpenDetail;

  const ResponseListCard({
    super.key,
    required this.response,
    required this.index,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = response;
    final style = responseStatusStyle(r.status);
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      // Material transparan agar ink splash ListTile tidak tertutup DecoratedBox.
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
        shape: const Border(),
        leading: Container(
          width: 34,
          height: 34,
          decoration:  BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style:  TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: cs.primary,
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
          style:  TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
          ),
        ),
        subtitle: Text(
          r.submittedAt == null
              ? 'Waktu tidak diketahui'
              : _formatTime(r.submittedAt!),
          style:  TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: style.$2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    style.$1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: style.$3,
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: onOpenDetail,
                  style: OutlinedButton.styleFrom(
                    side:  BorderSide(color: cs.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child:  Text(
                    'Lihat Jawaban',
                    style: TextStyle(color: cs.primary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return "${local.day}/${local.month}/${local.year} $hh:$mm";
}
