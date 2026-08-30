import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/features/home/widgets/home_empty_card.dart';

/// Section "Aktivitas Respons Terbaru" pada beranda (maksimal 3 item)
class HomeRecentActivity extends StatelessWidget {
  final bool loading;
  final List<MyResponseItem> responses;
  final void Function(MyResponseItem item) onOpenResponse;

  const HomeRecentActivity({
    super.key,
    required this.loading,
    required this.responses,
    required this.onOpenResponse,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && responses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: AppLoadingIndicator.circular()),
      );
    }
    if (responses.isEmpty) {
      return const HomeEmptyCard(
        icon: Icons.history,
        message: 'Belum ada aktivitas respons.',
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < responses.take(3).length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Colors.black12),
            _ActivityItem(
              item: responses[i],
              onTap: () => onOpenResponse(responses[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu baris aktivitas respons
class _ActivityItem extends StatelessWidget {
  final MyResponseItem item;
  final VoidCallback onTap;

  const _ActivityItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE2F3F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFF2A9D8F),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: RichTextView(
                          text: "Anda mengerjakan '${item.formTitle}'",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: kFontBold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(item.submittedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (item.formLink.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Kode: ${item.formLink}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime? dt) {
  if (dt == null) return 'Baru saja';
  final local = dt.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  if (diff.inDays < 30) return '${diff.inDays} hari lalu';
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return "${local.day}/${local.month}/${local.year} $hh:$mm";
}
