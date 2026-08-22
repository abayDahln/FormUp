import 'package:flutter/material.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/responses/widgets/response_status.dart';

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
    final r = response;
    final style = responseStatusStyle(r.status);
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
          r.submittedAt == null
              ? 'Waktu tidak diketahui'
              : _formatTime(r.submittedAt!),
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F4),
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
                    side: const BorderSide(color: kAuthPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text(
                    'Lihat Jawaban',
                    style: TextStyle(color: kAuthPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return "${local.day}/${local.month}/${local.year} $hh:$mm";
}
