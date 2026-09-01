import 'package:flutter/material.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form_runner/widgets/form_start_banner_card.dart';
import 'package:form_up/features/form_runner/widgets/form_start_info_card.dart';
import 'package:form_up/features/form_runner/widgets/form_start_status_info.dart';

/// Screen awal form - muncul sebelum masuk ke screen kerjakan form
/// Menampilkan: judul, deskripsi, banner, total soal, timer, token, jam buka/tutup, tombol Mulai
class FormStartScreen extends StatefulWidget {
  final String formLink;

  const FormStartScreen({super.key, required this.formLink});

  @override
  State<FormStartScreen> createState() => _FormStartScreenState();
}

class _FormStartScreenState extends State<FormStartScreen> {
  bool _loading = true;
  String? _error;
  PublicFormInfo? _formInfo;
  List<MyAttempt> _myAttempts = [];
  bool _validatingToken = false;
  String? _tokenError;

  final _tokenController = TextEditingController();
  final _feedbackController = TextEditingController();
  String _feedbackReason = 'General Feedback';
  bool _submittingFeedback = false;
  FormFeedbackItem? _myFeedback;
  bool _loadingFeedback = false;

  static const _feedbackReasons = [
    'General Feedback',
    'Inappropriate Content',
    'Misleading Information',
    'Bug / Technical Issue',
  ];

  @override
  void initState() {
    super.initState();
    _tokenController.addListener(() {
      if (_tokenError != null) setState(() => _tokenError = null);
    });
    _loadFormInfo();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadFormInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final info = await PublicFormService.getFormInfo(widget.formLink);

      // Cek apakah pemilik
      if (info.isOwner && mounted) {
        setState(() {
          _error = "Anda tidak dapat mengisi form yang Anda buat sendiri";
          _loading = false;
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        _formInfo = info;
      });

      await _loadCompletionState();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AuthService.errorMessage(e);
        _loading = false;
      });
      return;
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCompletionState() async {
    if (!mounted) return;
    if (AuthService.token == null || _formInfo == null) {
      setState(() {
        _myAttempts = [];
        _myFeedback = null;
      });
      return;
    }

    try {
      final attempts = await PublicFormService.getMyAttempts(widget.formLink);
      if (!mounted) return;
      setState(() => _myAttempts = attempts);
    } catch (_) {
      if (!mounted) return;
      setState(() => _myAttempts = []);
    }

    // Muat umpan balik hanya jika sudah pernah mengerjakan
    if (_myAttempts.isNotEmpty && _formInfo != null) {
      setState(() => _loadingFeedback = true);
      try {
        final fb = await FormService.getMyFeedback(_formInfo!.id);
        if (!mounted) return;
        setState(() => _myFeedback = fb);
      } catch (_) {
        if (!mounted) return;
        setState(() => _myFeedback = null);
      } finally {
        if (mounted) setState(() => _loadingFeedback = false);
      }
    } else {
      setState(() => _myFeedback = null);
    }
  }

  Future<void> _startForm() async {
    final info = _formInfo!;

    // Validasi token jika diperlukan
    if (info.requiresToken) {
      final token = _tokenController.text.trim();
      if (token.isEmpty) {
        setState(() => _tokenError = "Masukkan token akses form");
        return;
      }

      setState(() {
        _validatingToken = true;
        _tokenError = null;
      });

      try {
        await PublicFormService.getQuestions(widget.formLink, token: token);
        if (!mounted) return;
        setState(() => _validatingToken = false);
        _showConfirmDialog();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _validatingToken = false;
          _tokenError = AuthService.errorMessage(e);
        });
      }
      return;
    }

    _showConfirmDialog();
  }

  /// Dialog konfirmasi sebelum mulai mengerjakan form
  void _showConfirmDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Mulai Mengerjakan?",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        content: const Text(
          "Apakah Anda yakin ingin memulai pengerjaan form ini?",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Batal",
                style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAuthPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final router = AppRouter.of(this.context);
              Navigator.of(context).pop();
              await router.push(AppPage.formRunner, {
                'code': widget.formLink,
                'token': _tokenController.text.trim(),
              });
              if (!mounted) return;
              await _loadCompletionState();
            },
            child: const Text("Ya, Mulai"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          "Informasi Form",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: AuthBackground(plain: true,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingOverlay();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFC0392B)),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: "Kembali",
                onPressed: () => AppRouter.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    final info = _formInfo!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner - hanya ditampilkan jika banner terisi
          if (info.bannerImage != null && info.bannerImage!.trim().isNotEmpty) ...[
            FormStartBannerCard(bannerImage: info.bannerImage!),
            const SizedBox(height: 16),
          ],

          // Kartu informasi form (judul, deskripsi, jumlah soal, timer, jam buka/tutup, token)
          FormStartInfoCard(
            info: info,
            tokenController: _tokenController,
            tokenError: _tokenError,
          ),

          // Status info (one response, requires login)
          if (info.oneResponse || info.requiresLogin) ...[
            const SizedBox(height: 16),
            FormStartStatusInfo(
              oneResponse: info.oneResponse,
              requiresLogin: info.requiresLogin,
            ),
          ],

          const SizedBox(height: 24),

          if (_myAttempts.isNotEmpty) ...[
            const Text(
              "Anda sudah menyelesaikan form ini.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _openResponseHistory,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kAuthPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text("Lihat Respon", style: TextStyle(color: kAuthPrimary, fontWeight: FontWeight.bold, fontFamily: kFontBold)),
            ),
            const SizedBox(height: 12),
          ],

          // Tombol Mulai / Kerjakan Ulang
          AuthPrimaryButton(
            label: _myAttempts.isNotEmpty ? "Kerjakan Ulang" : "Mulai Mengerjakan",
            loading: _validatingToken,
            onPressed: _validatingToken ? null : _startForm,
          ),

          // Umpan balik — hanya jika sudah pernah mengerjakan, 1x per user
          if (_myAttempts.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(height: 1, color: Color(0x1FBDC9C8)),
            const SizedBox(height: 16),
            const Text(
              "Umpan Balik untuk Form ini",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: kFontBold, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              _myFeedback != null ? "Kamu sudah mengirim umpan balik untuk form ini." : "Hanya terlihat jika kamu sudah mengerjakan form ini. Satu umpan balik per form.",
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (_loadingFeedback)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
            else if (_myFeedback != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1FBDC9C8)),
                  boxShadow: softShadow(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text("Umpan Balik Kamu", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kAuthPrimary)),
                      Text(
                        "${_myFeedback!.createdAt.day}/${_myFeedback!.createdAt.month}/${_myFeedback!.createdAt.year}",
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text("Kategori: ${_myFeedback!.reason}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kAuthPrimary)),
                    if (_myFeedback!.description != null && _myFeedback!.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_myFeedback!.description!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    ],
                    const SizedBox(height: 8),
                    const Text("Umpan balik hanya bisa dikirim satu kali per form.", style: TextStyle(fontSize: 11, color: Colors.black38, fontStyle: FontStyle.italic)),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1FBDC9C8)),
                  boxShadow: softShadow(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Alasan Umpan Balik", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _feedbackReason,
                      decoration: formUpInputDecoration(hintText: 'Pilih alasan umpan balik'),
                      items: [for (final r in _feedbackReasons) DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))],
                      onChanged: _submittingFeedback ? null : (v) { if (v != null) setState(() => _feedbackReason = v); },
                    ),
                    const SizedBox(height: 12),
                    const Text("Deskripsi Umpan Balik", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _feedbackController,
                      maxLines: 3,
                      enabled: !_submittingFeedback,
                      decoration: formUpInputDecoration(hintText: 'Jelaskan umpan balik atau masalah...'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submittingFeedback ? null : _submitFeedback,
                        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: _submittingFeedback
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text("Kirim Umpan Balik", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _openResponseHistory() {
    final info = _formInfo;
    if (info == null) return;
    AppRouter.of(context).push(AppPage.historyFormDetail, {
      'formLink': widget.formLink,
      'formTitle': info.title,
    });
  }

  Future<void> _submitFeedback() async {
    if (_myFeedback != null) {
      showAuthToast(context, 'Kamu sudah mengirim umpan balik untuk form ini', isError: true);
      return;
    }
    final desc = _feedbackController.text.trim();
    if (desc.isEmpty) {
      showAuthToast(context, 'Deskripsi umpan balik wajib diisi', isError: true);
      return;
    }
    final formId = _formInfo?.id;
    if (formId == null) {
      showAuthToast(context, 'Form tidak ditemukan', isError: true);
      return;
    }
    setState(() => _submittingFeedback = true);
    try {
      await FormService.submitFeedback(formId, reason: _feedbackReason, description: desc);
      if (!mounted) return;
      showAuthToast(context, 'Umpan balik berhasil dikirim');
      _feedbackController.clear();
      // Muat ulang agar tampil sebagai "sudah mengirim" dan tidak bisa kirim lagi
      final fb = await FormService.getMyFeedback(formId);
      if (!mounted) return;
      setState(() => _myFeedback = fb ?? FormFeedbackItem(id: 0, formId: formId, formTitle: _formInfo?.title ?? '', userName: '', reason: _feedbackReason, description: desc, createdAt: DateTime.now()));
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _submittingFeedback = false);
    }
  }
}
