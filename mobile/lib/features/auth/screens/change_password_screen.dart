import 'package:flutter/material.dart';
import 'package:form_up/core/utils/action_debouncer.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/router/app_router.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!AppDebouncer.tryAcquire('auth:changePassword')) return;
    if (_loading) return;
    final current = _currentController.text;
    final newPassword = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      showAuthToast(context, 'Semua field wajib diisi', isError: true);
      return;
    }
    if (newPassword.length < 8) {
      showAuthToast(context, 'Kata sandi baru minimal 8 karakter', isError: true);
      return;
    }
    if (newPassword == current) {
      showAuthToast(context, 'Kata sandi baru tidak boleh sama dengan yang lama', isError: true);
      return;
    }
    if (newPassword != confirm) {
      showAuthToast(context, 'Konfirmasi kata sandi tidak cocok', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.changePassword(
        currentPassword: current,
        newPassword: newPassword,
      );
      if (!mounted) return;
      showAuthToast(context, 'Kata sandi berhasil diubah');
      AppRouter.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape:  Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
        leading: IconButton(
          icon:  Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title:  Text(
          "Ubah Kata Sandi",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
          ),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _loading,
        child: AuthBackground(
          plain: true,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                         Text(
                          "Masukkan kata sandi saat ini dan kata sandi baru Anda.",
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 20),
                        AuthTextField(
                          controller: _currentController,
                          hint: "Kata Sandi Saat Ini",
                          label: "Kata Sandi Saat Ini",
                          icon: Icons.lock_outline,
                          obscure: true,
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _newController,
                          hint: "Kata Sandi Baru",
                          label: "Kata Sandi Baru",
                          icon: Icons.lock_reset,
                          obscure: true,
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _confirmController,
                          hint: "Konfirmasi Kata Sandi Baru",
                          label: "Konfirmasi Kata Sandi Baru",
                          icon: Icons.lock_outline,
                          obscure: true,
                        ),
                        const SizedBox(height: 14),
                         Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Kata sandi baru minimal 8 karakter.",
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AuthPrimaryButton(
                    label: _loading ? "Menyimpan..." : "Simpan",
                    pill: true,
                    loading: _loading,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
