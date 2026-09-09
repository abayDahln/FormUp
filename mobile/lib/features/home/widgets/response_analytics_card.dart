import 'package:flutter/material.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Kartu form pada daftar responden (legacy)
class ResponseAnalyticsCard extends StatelessWidget {
  final FormData form;
  final VoidCallback onTap;

  const ResponseAnalyticsCard({
    super.key,
    required this.form,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ResponseAnalyticsTile(form: form, onTap: onTap, showDivider: false);
  }
}

/// M3 list tile untuk responden — dipakai di dalam grouped container dengan Divider
class ResponseAnalyticsTile extends StatelessWidget {
  final FormData form;
  final VoidCallback onTap;
  final bool showDivider;

  const ResponseAnalyticsTile({
    super.key,
    required this.form,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:  Icon(
                    Icons.groups_outlined,
                    color: cs.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichTextView(
                        text: form.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:  TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${form.responseCount} respons',
                        style:  TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                 Text(
                  'Responden',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, thickness: 1, color: cs.outlineVariant.withValues(alpha: 0.45)),
      ],
    );
  }
}
