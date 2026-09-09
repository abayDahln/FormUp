import 'package:flutter/material.dart';
import 'package:form_up/core/router/app_router.dart';

/// Kartu cantik pengganti blok `<FORM_CONTEXT>` mentah yang kadang di-echo
/// AI di dalam jawabannya: judul + deskripsi + jumlah soal (TANPA id),
/// dan bisa diketuk untuk langsung membuka screen detail form.
class FormContextCard extends StatelessWidget {
  final int? formId;
  final String title;
  final String description;
  final int? questionCount;

  const FormContextCard._({
    required this.title,
    required this.description,
    this.formId,
    this.questionCount,
  });

  static String _clean(String? s) => (s ?? '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Parse isi blok `<FORM_CONTEXT> ... </FORM_CONTEXT>`. Toleran terhadap
  /// variasi format echo model (Form ID / Title / Description / Question Count).
  factory FormContextCard.fromBlock(String body) {
    final idMatch =
        RegExp(r'Form\s*ID\s*:\s*(\d+)', caseSensitive: false).firstMatch(body);
    final title = _clean(
      RegExp(r'Title\s*:\s*(.+)', caseSensitive: false)
          .firstMatch(body)
          ?.group(1),
    );
    final desc = _clean(
      RegExp(
        r'Description\s*:\s*([\s\S]*?)(?=\n\s*(?:Question\s*Count|Title|Form\s*ID)\s*:|$)',
        caseSensitive: false,
      ).firstMatch(body)?.group(1),
    );
    final qn = int.tryParse(
      RegExp(r'Question\s*Count\s*:\s*(\d+)', caseSensitive: false)
          .firstMatch(body)
          ?.group(1)
          ?? '',
    );
    return FormContextCard._(
      formId: int.tryParse(idMatch?.group(1) ?? ''),
      title: title.isEmpty ? 'Form' : title,
      description: desc,
      questionCount: qn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tappable = formId != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: tappable
            ? () => AppRouter.of(context)
                .push(AppPage.formDetail, {'formId': formId})
            : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 15,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.5, color: cs.onSurfaceVariant),
                      ),
                    ],
                    if (questionCount != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.quiz_outlined,
                                size: 10, color: cs.primary),
                            const SizedBox(width: 4),
                            Text(
                              '$questionCount soal',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (tappable)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child:
                      Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
