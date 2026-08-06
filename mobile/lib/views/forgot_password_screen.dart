import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import '../services/auth_service.dart';
import '../app_router.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      showAuthToast(context, "Masukkan email terlebih dahulu");
      return;
    }
    if (!AuthService.isValidEmail(email)) {
      showAuthToast(context, "Format email tidak valid");
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.forgotPassword(email);
      if (!mounted) return;
      AppRouter.of(context).push(AppPage.otp, {'email': email});
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
                          title: "Lupa Kata Sandi",
                          subtitle:
                              "Masukkan email yang terdaftar.\nKami akan mengirimkan kode OTP ke email Anda.",
                        ),
                        const SizedBox(height: 40),
                        AuthCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AuthTextField(
                                controller: _emailController,
                                hint: "Email",
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 22),
                              AuthPrimaryButton(
                                label: "Kirim OTP",
                                pill: true,
                                loading: _loading,
                                onPressed: _sendOtp,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AuthBottomPill(
                          link: "Kembali ke Masuk",
                          onTap: () => AppRouter.of(context).pop(),
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
