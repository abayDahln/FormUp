import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import '../services/auth_service.dart';
import '../app_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showAuthToast(context, "Email dan kata sandi wajib diisi");
      return;
    }
    if (!AuthService.isValidEmail(email)) {
      showAuthToast(context, "Format email tidak valid");
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await AuthService.login(email, password);
      if (!mounted) return;
      final displayName = result.fullname.isEmpty
          ? result.username
          : result.fullname;
      AppRouter.of(context).goHome(displayName);
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
                          title: "Masuk",
                          subtitle: "Masuk untuk mengelola formulir Anda",
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
                              const SizedBox(height: 17),
                              AuthTextField(
                                controller: _passwordController,
                                hint: "Kata Sandi",
                                icon: Icons.lock_outline,
                                obscure: true,
                              ),
                              const SizedBox(height: 16),
                              AuthPrimaryButton(
                                label: "Masuk",
                                loading: _loading,
                                onPressed: _login,
                              ),
                              const SizedBox(height: 24),
                              Align(
                                alignment: Alignment.center,
                                child: GestureDetector(
                                  onTap: () {
                                    AppRouter.of(context)
                                        .push(AppPage.forgotPassword);
                                  },
                                  child: const Text(
                                    "Lupa Kata Sandi?",
                                    style: TextStyle(
                                      color: kAuthPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: kFontBold,
                                      decoration: TextDecoration.underline,
                                      decorationColor: kAuthPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AuthBottomPill(
                          question: "Pengguna baru? ",
                          link: "Daftar",
                          onTap: () {
                            AppRouter.of(context).push(AppPage.register);
                          },
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
