import 'package:flutter/material.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Kartu terbitkan / tarik form dengan switch
class FormDetailPublishCard extends StatelessWidget {
  final FormData form;
  final VoidCallback onToggle;

  const FormDetailPublishCard({
    super.key,
    required this.form,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: Icon(
            form.status == 'published'
                ? Icons.publish
                : Icons.visibility_off_outlined,
            color: cs.primary,
          ),
          title: Text(
            form.status == 'published' ? 'Tarik (kembali ke draf)' : 'Terbitkan form',
            style: TextStyle(fontSize: 14, color: cs.onSurface),
          ),
          subtitle: Text(
            form.status == 'published'
                ? 'Form sedang terbuka untuk respons.'
                : 'Form belum terbuka untuk responden.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          trailing: Switch(
            value: form.status == 'published',
            activeTrackColor: cs.primary,
            onChanged: (_) => onToggle(),
          ),
        ),
      ),
    );
  }
}
