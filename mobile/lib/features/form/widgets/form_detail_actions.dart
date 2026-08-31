import 'package:flutter/material.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/theme.dart';
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
              'Lihat Respon',
              () => onPush(AppPage.formAnalytics, {
                'formId': form.id,
                'title': richToPlainText(form.title),
              }),
            ),
            _divider(),
            _ActionTile(
              Icons.feedback_outlined,
              'Lihat Umpan Balik',
              () => onPush(AppPage.formFeedbacks, {
                'formId': form.id,
                'formTitle': richToPlainText(form.title),
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
            _divider(),
            _ActionTile(
              Icons.delete_outline,
              'Hapus Form',
              () => _confirmDelete(context, form),
              danger: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, FormData form) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Form?', style: TextStyle(fontFamily: kFontBold)),
        content: Text('Form "${richToPlainText(form.title)}" akan dihapus permanen. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kDangerColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FormService.deleteForm(form.id);
      if (!context.mounted) return;
      showAuthToast(context, 'Form berhasil dihapus');
      formsVersion.value++;
      AppRouter.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
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
  final bool danger;

  const _ActionTile(this.icon, this.label, this.onTap, {this.locked = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? kDangerColor : kAuthPrimary;
    return ListTile(
      leading: Icon(
        locked ? Icons.lock_outline : icon,
        color: locked ? Colors.black38 : color,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: danger ? FontWeight.bold : FontWeight.normal,
          fontFamily: danger ? kFontBold : null,
          color: danger ? kDangerColor : (locked ? Colors.black38 : Colors.black87),
        ),
      ),
      trailing: Icon(Icons.chevron_right, size: 18, color: danger ? kDangerColor : Colors.grey),
      onTap: onTap,
    );
  }
}
