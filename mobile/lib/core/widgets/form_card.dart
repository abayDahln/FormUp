import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart'
    show kRadius, kFontBold, formStatusStyle, elevationShadow, ShadowLevel, showAuthToast;
import 'package:form_up/core/widgets/form_share_sheet.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';

/// Kartu form seragam – hanya tap ke detail, tanpa aksi cepat titik tiga
class FormCard extends StatelessWidget {
  final FormData form;
  final VoidCallback onTap;

  const FormCard({
    super.key,
    required this.form,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = formStatusStyle(form.status);
    // M3 Card dengan shadow jelas agar tidak samar di #F8F9FA (contoh: clipBehavior hardEdge + InkWell splash)
    return Card(
      color: cs.surface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      child: InkWell(
        splashColor: cs.primary.withValues(alpha: 0.08),
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
                child: Icon(
                  Icons.description_outlined,
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Dibuat: ${_formatDate(form.createdAt ?? form.updatedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: style.chipDecoration(context),
                          child: Text(
                            style.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: kFontBold,
                              color: style.fgOf(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.people_outline,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${form.responseCount} respons',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return 'Baru saja';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final local = dt.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}



/// Panel aksi cepat (titik tiga)
bool _quickActionsOpen = false;

Future<void> showFormQuickActions(
  BuildContext context,
  FormData form, {
  required Future<void> Function() onChanged,
}) async {
  if (_quickActionsOpen) return;
  _quickActionsOpen = true;
  final style = formStatusStyle(form.status);
  try {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: elevationShadow(ShadowLevel.high),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.description_outlined,
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: style.chipDecoration(context),
                            child: Text(
                              style.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: kFontBold,
                                color: style.fgOf(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.people_outline,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${form.responseCount} respons',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 4),
          _sheetAction(
            cs: cs,
            icon: form.responseCount > 0
                ? Icons.lock_outline
                : Icons.edit_outlined,
            label: 'Edit Soal & Jawaban',
            muted: form.responseCount > 0,
            onTap: form.responseCount > 0
                ? () => showAuthToast(
                      context,
                      'Soal tidak dapat diubah karena form sudah memiliki respons',
                      isError: true,
                    )
                : () => _closeAndPush(
                    sheetContext,
                    context,
                    AppPage.formQuestions,
                    {'formId': form.id},
                  ),
          ),
          _sheetAction(
            cs: cs,
            icon: Icons.visibility_outlined,
            label: 'Pratinjau',
            onTap: () => _closeAndPush(
              sheetContext,
              context,
              AppPage.formPreview,
              {'formId': form.id},
            ),
          ),
          _sheetAction(
            cs: cs,
            icon: Icons.people_outline,
            label: 'Lihat Respon',
            onTap: () => _closeAndPush(
              sheetContext,
              context,
              AppPage.formRespon,
              {'formId': form.id, 'title': richToPlainText(form.title)},
            ),
          ),
          _sheetAction(
            cs: cs,
            icon: Icons.settings_outlined,
            label: 'Setting Form',
            onTap: () => _closeAndPush(
              sheetContext,
              context,
              AppPage.formMaker,
              {'formId': form.id},
            ),
          ),
          _sheetAction(
            cs: cs,
            icon: Icons.share_outlined,
            label: 'Bagikan Form',
            onTap: () {
              if (shareSheetBusy) return;
              Navigator.pop(sheetContext);
              showFormShareSheet(context, form);
            },
          ),
          Divider(height: 1, color: cs.outlineVariant),
          // ponytail: publikasi eksplisit via toggle
          ListTile(
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
            trailing: Switch(
              value: form.status == 'published',
              activeTrackColor: cs.primary,
              onChanged: (_) {
                Navigator.pop(sheetContext);
                toggleFormPublish(context, form, onChanged: onChanged);
              },
            ),
          ),
const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      );
      },
  );
  } finally {
    _quickActionsOpen = false;
  }
}

Widget _sheetAction({
  required ColorScheme cs,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool muted = false,
}) {
  return ListTile(
    leading: Icon(icon, color: cs.primary),
    title: Text(
      label,
      style: TextStyle(
        fontSize: 14,
        color: muted ? cs.onSurfaceVariant : cs.onSurface,
      ),
    ),
    trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
    onTap: onTap,
  );
}

void _closeAndPush(
  BuildContext sheetContext,
  BuildContext context,
  AppPage page,
  Map<String, dynamic> args,
) {
  Navigator.pop(sheetContext);
  AppRouter.of(context).push(page, args);
}

/// Terbit/tarik form
Future<void> toggleFormPublish(
  BuildContext context,
  FormData form, {
  required Future<void> Function() onChanged,
}) async {
  final publish = form.status != 'published';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return AlertDialog(
      title: Text(
        publish ? 'Terbitkan Form' : 'Tarik Form',
        style: const TextStyle(fontFamily: kFontBold),
      ),
      content: Text(
        publish
            ? 'Form akan tersedia untuk dikerjakan responden.'
            : 'Form akan berhenti menerima respons baru dan kembali menjadi draf.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            publish ? 'Terbit' : 'Tarik',
            style: TextStyle(color: cs.primary),
          ),
        ),
      ],
    );
    },
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await FormService.publish(form.id);
    if (!context.mounted) return;
    showAuthToast(
      context,
      publish ? 'Form berhasil diterbitkan' : 'Form berhasil ditarik',
    );
    await onChanged();
  } catch (e) {
    if (!context.mounted) return;
    showAuthToast(context, AuthService.errorMessage(e), isError: true);
  }
}

