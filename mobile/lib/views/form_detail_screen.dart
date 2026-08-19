import 'package:flutter/material.dart';

import 'auth_widgets.dart';
import 'form_share_sheet.dart';
import 'rich_editor.dart';
import '../app_router.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';

/// Halaman detail form + aksi kelola
class FormDetailScreen extends StatefulWidget {
  final int formId;
  final FormData? initial;

  const FormDetailScreen({super.key, required this.formId, this.initial});

  @override
  State<FormDetailScreen> createState() => _FormDetailScreenState();
}

class _FormDetailScreenState extends State<FormDetailScreen> {
  FormData? _form;

  @override
  void initState() {
    super.initState();
    _form = widget.initial;
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await FormService.getForm(widget.formId);
      if (!mounted) return;
      setState(() => _form = FormData.fromJson(data));
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  void _push(AppPage page, Map<String, dynamic> args) {
    AppRouter.of(context).push(page, args);
  }

  Future<void> _openShare(FormData form) => showFormShareSheet(context, form);

  Future<void> _togglePublish() async {
    final form = _form;
    if (form == null) return;
    final publish = form.status != 'published';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
              style: const TextStyle(color: kAuthPrimary),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FormService.publish(form.id);
      if (!mounted) return;
      showAuthToast(
        context,
        publish ? 'Form berhasil diterbitkan' : 'Form berhasil ditarik',
      );
      await _fetch();
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = _form;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title: const Text(
          'Detail Form',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: form == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _buildHeader(form),
                const SizedBox(height: 16),
                _buildActions(form),
                const SizedBox(height: 16),
                _buildPublish(form),
              ],
            ),
    );
  }

  Widget _buildHeader(FormData form) {
    final style = formStatusStyle(form.status);
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (form.bannerImage != null && form.bannerImage!.trim().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  profileImageUrl(form.bannerImage),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, _, _) => Container(
                    width: double.infinity,
                    color: const Color(0xFFF0F4F4),
                    child: const Icon(
                      Icons.broken_image_outlined,
                      size: 32,
                      color: Colors.grey,
                    ),
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
                  color: kPrimarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: kAuthPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichTextView(
                  text: form.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _badge(style),
              const SizedBox(width: 8),
              const Icon(Icons.people_outline, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${form.responseCount} respons',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          if (form.description != null && form.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 12),
            RichTextView(
              text: form.description!,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Colors.black12),
          ],
          const SizedBox(height: 10),
          _infoRow(Icons.calendar_today_outlined, 'Dibuat: ${_formatDate(form.createdAt ?? form.updatedAt)}'),
          const SizedBox(height: 4),
          _infoRow(Icons.link, 'Kode form: ${form.formLink}'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _badge(FormStatusStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          color: style.fg,
        ),
      ),
    );
  }

  Widget _buildActions(FormData form) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            _actionTile(
              Icons.edit_outlined,
              'Edit Soal & Jawaban',
              () => _push(AppPage.formQuestions, {'formId': form.id}),
            ),
            _actionDivider(),
            _actionTile(
              Icons.visibility_outlined,
              'Pratinjau',
              () => _push(AppPage.formPreview, {'formId': form.id}),
            ),
            _actionDivider(),
            _actionTile(
              Icons.people_outline,
              'Lihat Respons',
              () => _push(AppPage.formResponses, {
                'formId': form.id,
                'title': richToPlainText(form.title),
              }),
            ),
            _actionDivider(),
            _actionTile(
              Icons.settings_outlined,
              'Setting Form',
              () => _push(AppPage.formMaker, {'formId': form.id}),
            ),
            _actionDivider(),
            _actionTile(
              Icons.share_outlined,
              'Bagikan Form',
              () => _openShare(form),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: kAuthPrimary),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _actionDivider() =>
      const Divider(height: 1, indent: 56, color: Colors.black12);

  Widget _buildPublish(FormData form) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: Icon(
            form.status == 'published'
                ? Icons.publish
                : Icons.visibility_off_outlined,
            color: kAuthPrimary,
          ),
          title: Text(
            form.status == 'published' ? 'Tarik (kembali ke draf)' : 'Terbitkan form',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          subtitle: Text(
            form.status == 'published'
                ? 'Form sedang terbuka untuk respons.'
                : 'Form belum terbuka untuk responden.',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          trailing: Switch(
            value: form.status == 'published',
            activeTrackColor: kAuthPrimary,
            onChanged: (_) => _togglePublish(),
          ),
        ),
      ),
    );
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
}
