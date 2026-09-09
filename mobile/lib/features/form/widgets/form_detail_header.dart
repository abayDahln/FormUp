import 'package:flutter/material.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Kartu header detail form: banner, judul, badge status, info
class FormDetailHeader extends StatelessWidget {
  final FormData form;

  const FormDetailHeader({super.key, required this.form});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = formStatusStyle(form.status);
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (form.bannerImage != null && form.bannerImage!.trim().isNotEmpty) ...[
            AspectRatio(
              aspectRatio: 16 / 7,
              child: CachedRemoteImage(
                url: profileImageUrl(form.bannerImage),
                fit: BoxFit.cover,
                errorWidget: Container(
                  width: double.infinity,
                  color: cs.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 32,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: cs.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichTextView(
                  text: form.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Badge(style),
              const SizedBox(width: 8),
              Icon(Icons.people_outline, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '${form.responseCount} respons',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          if (form.description != null && form.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: 12),
            RichTextView(
              text: form.description!,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: cs.outlineVariant),
          ],
          const SizedBox(height: 10),
          _InfoRow(Icons.calendar_today_outlined,
              'Dibuat: ${_formatDate(form.createdAt ?? form.updatedAt)}'),
          const SizedBox(height: 4),
          _InfoRow(Icons.link, 'Kode Form: ${form.formLink}'),
        ],
      ),
    );
  }
}

/// Satu baris info kecil (ikon + teks)
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Badge status form
class _Badge extends StatelessWidget {
  final FormStatusStyle style;

  const _Badge(this.style);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
    );
  }
}

String _formatDate(DateTime? dt) {
  if (dt == null) return 'Baru saja';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final local = dt.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
