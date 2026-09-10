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

  /// Pantau Ujian hanya relevan untuk form tipe/mode ujian.
  final bool showExamMonitoring;

  /// Pantau Ujian hanya bisa dibuka bila form sudah terbit; saat draf
  /// tombol tampil nonaktif (bukan hilang) agar tidak membingungkan.
  final bool examMonitoringEnabled;
  final String examMonitoringDisabledHint;

  const FormDetailActions({
    super.key,
    required this.form,
    required this.onPush,
    required this.onShare,
    this.showExamMonitoring = true,
    this.examMonitoringEnabled = true,
    this.examMonitoringDisabledHint = 'Terbitkan form dulu untuk memantau ujian',
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
              'Responden',
              () => onPush(AppPage.formAnalytics, {
                'formId': form.id,
                'title': richToPlainText(form.title),
              }),
            ),
            _divider(),
            if (showExamMonitoring) ...[
              _ActionTile(
                Icons.shield_outlined,
                'Pantau Ujian',
                () => onPush(AppPage.examMonitoring, {
                  'formId': form.id,
                  'title': richToPlainText(form.title),
                }),
                disabled: !examMonitoringEnabled,
                disabledHint: examMonitoringDisabledHint,
              ),
              _divider(),
            ],
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
      // _invalidateCaches() sudah bump formsVersion
      AppRouter.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }
}

Widget _divider() {
  return Builder(builder: (context) {
    return Divider(height: 1, indent: 56, color: Theme.of(context).colorScheme.outlineVariant);
  });
}

/// Satu baris aksi (ListTile)
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool locked;
  final bool danger;
  final bool disabled;
  final String? disabledHint;

  const _ActionTile(this.icon, this.label, this.onTap, {this.locked = false, this.danger = false, this.disabled = false, this.disabledHint});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = danger ? kDangerColor : cs.primary;
    final inactive = locked || disabled;
    return ListTile(
      leading: Icon(
        locked ? Icons.lock_outline : icon,
        color: inactive ? cs.onSurfaceVariant : color,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: danger ? FontWeight.bold : FontWeight.normal,
          fontFamily: danger ? kFontBold : null,
          color: danger && !disabled ? kDangerColor : (inactive ? cs.onSurfaceVariant : cs.onSurface),
        ),
      ),
      trailing: Icon(Icons.chevron_right, size: 18, color: inactive ? cs.outline : cs.onSurfaceVariant),
      onTap: disabled
          ? () {
              if (disabledHint != null) {
                showAuthToast(context, disabledHint!, isError: true);
              }
            }
          : onTap,
    );
  }
}
