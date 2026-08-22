import 'package:flutter/material.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Panel daftar aksi kelola form (edit, pratinjau, respons, setting, bagikan)
class FormDetailActions extends StatelessWidget {
  final FormData form;
  final void Function(AppPage page, Map<String, dynamic> args) onPush;
  final Future<void> Function(FormData form) onShare;

  const FormDetailActions({
    super.key,
    required this.form,
    required this.onPush,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            _ActionTile(
              Icons.edit_outlined,
              'Edit Soal & Jawaban',
              form.responseCount > 0
                  ? () => showAuthToast(
                        context,
                        'Soal tidak dapat diubah karena form sudah memiliki respons',
                        isError: true,
                      )
                  : () => onPush(AppPage.formQuestions, {'formId': form.id}),
              locked: form.responseCount > 0,
            ),
            _divider(),
            _ActionTile(
              Icons.visibility_outlined,
              'Pratinjau',
              () => onPush(AppPage.formPreview, {'formId': form.id}),
            ),
            _divider(),
            _ActionTile(
              Icons.people_outline,
              'Lihat Respons',
              () => onPush(AppPage.formResponses, {
                'formId': form.id,
                'title': richToPlainText(form.title),
              }),
            ),
            _divider(),
            _ActionTile(
              Icons.settings_outlined,
              'Setting Form',
              () => onPush(AppPage.formMaker, {'formId': form.id}),
            ),
            _divider(),
            _ActionTile(
              Icons.share_outlined,
              'Bagikan Form',
              () => onShare(form),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _divider() =>
    const Divider(height: 1, indent: 56, color: Colors.black12);

/// Satu baris aksi (ListTile)
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool locked;

  const _ActionTile(this.icon, this.label, this.onTap, {this.locked = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        locked ? Icons.lock_outline : icon,
        color: kAuthPrimary,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: locked ? Colors.black38 : Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }
}
