import 'package:flutter/material.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Bottom sheet detail jawaban satu respons
class ResponseDetailSheet extends StatelessWidget {
  final ResponseDetailData detail;

  const ResponseDetailSheet({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (detail.respondentName ?? '').trim().isEmpty
                            ? 'Detail Respons'
                            : detail.respondentName!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                          color: Colors.black87,
                        ),
                      ),
                      if (detail.submittedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatDetailTime(detail.submittedAt!),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: detail.answers.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada jawaban.',
                      style: TextStyle(fontSize: 13, color: Colors.black45),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: detail.answers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final a = detail.answers[i];
                      final answered = a.display.trim().isNotEmpty;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichTextView(
                              text: a.question,
                              prefix: '${i + 1}. ',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: kFontBold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              answered ? a.display : 'Tidak dijawab',
                              style: TextStyle(
                                fontSize: 12,
                                color: answered
                                    ? Colors.black87
                                    : Colors.black45,
                                fontStyle: answered
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDetailTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return "${local.day}/${local.month}/${local.year} $hh:$mm";
  }
}
