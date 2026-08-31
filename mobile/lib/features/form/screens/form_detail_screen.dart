import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';

import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/form_share_sheet.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/features/form/widgets/form_detail_actions.dart';
import 'package:form_up/features/form/widgets/form_detail_header.dart';
import 'package:form_up/features/form/widgets/form_detail_publish_card.dart';

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
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xCCBDC9C8)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title: const Text(
          'Detail Form',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: form == null
          ? const AppLoadingOverlay()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                FormDetailHeader(form: form),
                const SizedBox(height: 16),
                FormDetailActions(form: form, onPush: _push, onShare: _openShare),
                const SizedBox(height: 16),
                FormDetailPublishCard(form: form, onToggle: _togglePublish),
              ],
            ),
    );
  }
}
