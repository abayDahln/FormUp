import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import '../services/auth_service.dart';
import '../app_router.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_loading) return;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < 8) {
      showAuthToast(context, "Kata sandi minimal 8 karakter", isError: true);
      return;
    }
    if (newPassword != confirmPassword) {
      showAuthToast(context, "Konfirmasi kata sandi tidak cocok", isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.resetPassword(
        email: widget.email,
        otp: widget.otp,
        newPassword: newPassword,
      );
      if (!mounted) return;
      showAuthToast(context, "Kata sandi berhasil direset, silakan masuk");
      AppRouter.of(context).resetToLogin();
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthBg,
      body: AuthBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AuthTitle(
                          title: "Atur Ulang Kata Sandi",
                          subtitle:
                              "Buat kata sandi baru untuk akun Anda.\nMinimal 8 karakter.",
                        ),
                        const SizedBox(height: 40),
                        AuthCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AuthTextField(
                                controller: _newPasswordController,
                                hint: "Kata Sandi Baru",
                                icon: Icons.lock_outline,
                                obscure: true,
                              ),
                              const SizedBox(height: 17),
                              AuthTextField(
                                controller: _confirmPasswordController,
                                hint: "Konfirmasi Kata Sandi",
                                icon: Icons.lock_outline,
                                obscure: true,
                              ),
                              const SizedBox(height: 14),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: kAuthHint,
                                  ),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "Kata sandi minimal 8 karakter, kombinasi huruf dan angka.",
                                      style: TextStyle(
                                        color: kAuthHint,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              AuthPrimaryButton(
                                label: "Atur Ulang Kata Sandi",
                                pill: true,
                                loading: _loading,
                                onPressed: _resetPassword,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AuthBottomPill(
                          link: "Kembali ke Masuk",
                          onTap: () =>
                              AppRouter.of(context).resetToLogin(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
