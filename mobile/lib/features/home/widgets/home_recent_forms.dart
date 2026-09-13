import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/form_card.dart';
import 'package:form_up/features/home/widgets/home_empty_card.dart';

/// Section "Form Terbaru" pada beranda (maksimal 3 form) – hanya detail
class HomeRecentForms extends StatelessWidget {
  final bool loading;
  final List<FormData> forms;
  final void Function(FormData form) onOpenForm;

  const HomeRecentForms({
    super.key,
    required this.loading,
    required this.forms,
    required this.onOpenForm,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && forms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: AppLoadingOverlay(),
      );
    }
    if (forms.isEmpty) {
      return const HomeEmptyCard(
        icon: Icons.description_outlined,
        message: 'Belum ada form. Ketuk + untuk membuat.',
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
