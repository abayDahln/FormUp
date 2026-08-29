import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
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
      setState(() => _myAttempts = []);
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
      return const Center(child: CircularProgressIndicator());
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

          if (_myAttempts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F4E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Color(0xFF2E7D32),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Anda sudah selesai mengerjakan form ini.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AuthPrimaryButton(
                    label: "Lihat Respon",
                    onPressed: _openResponseHistory,
                  ),
                ],
              ),
            ),
          ],

          if (!(info.oneResponse && _myAttempts.isNotEmpty)) ...[
            const SizedBox(height: 24),

            // Tombol Mulai
            AuthPrimaryButton(
              label: "Mulai Mengerjakan",
              loading: _validatingToken,
              onPressed: _validatingToken ? null : _startForm,
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
}
