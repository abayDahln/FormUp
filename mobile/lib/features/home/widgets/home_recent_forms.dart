import 'package:flutter/material.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/form_card.dart';
import 'package:form_up/features/home/widgets/home_empty_card.dart';

/// Section "Form Terbaru" pada beranda (maksimal 3 form)
class HomeRecentForms extends StatelessWidget {
  final bool loading;
  final List<FormData> forms;
  final void Function(FormData form) onOpenForm;
  final void Function(FormData form) onQuickActions;

  const HomeRecentForms({
    super.key,
    required this.loading,
    required this.forms,
    required this.onOpenForm,
    required this.onQuickActions,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && forms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (forms.isEmpty) {
      return const HomeEmptyCard(
        icon: Icons.description_outlined,
        message: 'Belum ada form. Ketuk + untuk membuat.',
      );
    }
    return Column(
      children: [
        for (final form in forms.take(3)) ...[
          FormCard(
            form: form,
            onTap: () => onOpenForm(form),
            onQuickActions: () => onQuickActions(form),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
