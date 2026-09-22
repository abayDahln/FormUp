import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/connection_error_view.dart';
import 'package:form_up/core/widgets/empty_state.dart';
import 'package:form_up/core/widgets/loading_skeleton.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/form_card.dart';

/// Section "Form Terbaru" pada beranda (maksimal 3 form) – hanya detail
class HomeRecentForms extends StatelessWidget {
  final bool loading;
  final List<FormData> forms;
  final void Function(FormData form) onOpenForm;
  final String? loadError;
  final VoidCallback? onRetry;

  const HomeRecentForms({
    super.key,
    required this.loading,
    required this.forms,
    required this.onOpenForm,
    this.loadError,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && forms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SkeletonList.cards(itemCount: 3),
      );
    }
    if (forms.isEmpty) {
      if (loadError != null && onRetry != null) {
        return ConnectionErrorView(message: loadError!, onRetry: onRetry!);
      }
      return const EmptyState(
        icon: Icons.description_outlined,
        title: 'Belum ada form',
        message: 'Ketuk + untuk membuat form pertama Anda.',
      );
    }
    // G4: 1 kolom di phone (3 item, identik); tablet/desktop mengikuti
    // kolom grid aktual dengan baris penuh (kolom × 2: 2→4, 3→6, 4→8).
    if (!isTablet(context)) {
      return Column(
        children: [
          for (final form in forms.take(3)) ...[
            FormCard(
              form: form,
              onTap: () => onOpenForm(form),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Satu ambang dengan Form Saya (formGridColumns) + jumlah item
        // selalu baris penuh (kolom × 2).
        final cols = formGridColumns(constraints.maxWidth);
        return ResponsiveGrid(
          compact: true,
          columnCountFor: formGridColumns,
          children: [
            for (final form in forms.take(cols * 2))
              FormCard(
                form: form,
                onTap: () => onOpenForm(form),
              ),
          ],
        );
      },
    );
  }
}
