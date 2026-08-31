import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/admin_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Detail feedback untuk admin: pesan lengkap + info form terkait + aksi
class AdminFeedbackDetailScreen extends StatefulWidget {
  final AdminFeedbackItem feedback;

  const AdminFeedbackDetailScreen({super.key, required this.feedback});

  @override
  State<AdminFeedbackDetailScreen> createState() =>
      _AdminFeedbackDetailScreenState();
}

class _AdminFeedbackDetailScreenState extends State<AdminFeedbackDetailScreen> {
  bool _busy = false;
  AdminFormDetail? _form;
  bool _formLoading = true;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  Future<void> _loadForm() async {
    setState(() => _formLoading = true);
    try {
      final form = await AdminService.getFormDetail(widget.feedback.formId);
      if (!mounted) return;
      setState(() => _form = form);
    } catch (_) {
      // ponytail: info form gagal dimuat tidak fatal
    } finally {
      if (mounted) setState(() => _formLoading = false);
    }
  }

  Future<bool?> _confirm(String title, String content, String action,
      {bool danger = false}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: kFontBold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action,
                style: TextStyle(
                    color: danger ? kDangerColor : kAuthPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showAuthToast(context, success);
      await _loadForm();
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _takedown() async {
    final ok = await _confirm(
      'Takedown Form',
      'Form "${widget.feedback.formTitle}" akan disembunyikan dari publik.',
      'Takedown',
    );
    if (ok == true && mounted) {
      _run(() => AdminService.feedbackTakedown(widget.feedback.id),
          'Form di-takedown');
    }
  }

  void _restore() async {
    final ok = await _confirm(
      'Restore Form',
      'Form "${widget.feedback.formTitle}" akan bisa diakses publik kembali.',
      'Restore',
    );
    if (ok == true && mounted) {
      _run(() => AdminService.feedbackRestore(widget.feedback.id),
          'Form di-restore');
    }
  }

  void _dismiss() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            const Text('Hapus Feedback', style: TextStyle(fontFamily: kFontBold)),
        content: const Text('Feedback ini akan dihapus permanen. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Hapus', style: TextStyle(color: kDangerColor)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AdminService.dismissFeedback(widget.feedback.id);
      if (!mounted) return;
      showAuthToast(context, 'Feedback dihapus');
      setState(() => _dismissed = true);
      AppRouter.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fb = widget.feedback;
    final takenDown = _form?.takenDownAt != null;

    if (_dismissed) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "Detail Feedback",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // Pesan feedback
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kRadiusLg),
                boxShadow: softShadow(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: kPrimarySoft,
                        child: Text('F', style: TextStyle(color: kAuthPrimary)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fb.userName.isEmpty ? 'Anonim' : fb.userName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: kFontBold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(fb.userEmail,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Alasan',
                    style: TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    fb.reason.isEmpty ? '—' : fb.reason,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: Colors.black87),
                  ),
                  if (fb.description != null && fb.description!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Penjelasan',
                      style: TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      fb.description!,
                      style: const TextStyle(
                          fontSize: 14, height: 1.5, color: Colors.black87),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Info form terkait
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kRadiusLg),
                boxShadow: softShadow(),
              ),
              child: _formLoading
                  ? const Center(
                      child: Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: AppLoadingIndicator.inline()),
                    ))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FORM TERKAIT',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: kFontBold,
                              color: Colors.black45),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          fb.formTitle.isEmpty
                              ? 'Form #${fb.formId}'
                              : fb.formTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: kFontBold,
                            color: Colors.black87,
                          ),
                        ),
                        if (_form != null) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            children: [
                              _chip(_statusLabel(_form!.status),
                                  _statusColor(_form!.status)),
                              if (_form!.takenDownAt != null)
                                _chip('Taken Down', kDangerColor),
                              _chip('${_form!.responseCount} respons',
                                  Colors.grey),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text('Kode Form: ${_form!.formLink}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                          Text(
                              'Pemilik: ${_form!.owner.fullname ?? '-'} (${_form!.owner.email ?? '-'})',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ],
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () =>
                              AppRouter.of(context).push(AppPage.adminFormDetail,
                                  {'formId': fb.formId}),
                          icon: const Icon(Icons.visibility_outlined,
                              size: 18, color: kAuthPrimary),
                          label: const Text('Lihat Detail Form',
                              style: TextStyle(color: kAuthPrimary)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kAuthPrimary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // Aksi
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kRadiusLg),
                boxShadow: softShadow(),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      takenDown ? Icons.restore : Icons.block,
                      color: takenDown ? kSuccessColor : kWarningColor,
                    ),
                    title: Text(
                      takenDown ? 'Restore Form Terkait' : 'Takedown Form Terkait',
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        size: 18, color: Colors.grey),
                    onTap: takenDown ? _restore : _takedown,
                  ),
                  const Divider(height: 1, indent: 56, color: Colors.black12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_outline,
                        color: kDangerColor),
                    title: const Text('Hapus Feedback',
                        style: TextStyle(fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right,
                        size: 18, color: Colors.grey),
                    onTap: _dismiss,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return 'Terbit';
      case 'closed':
        return 'Ditutup';
      default:
        return 'Draft';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return kSuccessColor;
      case 'closed':
        return kWarningColor;
      default:
        return kInfoColor;
    }
  }
}

Widget _chip(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        fontFamily: kFontBold,
        color: color,
      ),
    ),
  );
}
