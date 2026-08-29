import 'package:flutter/material.dart';
import 'package:form_up/core/utils/action_debouncer.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/router/app_router.dart';

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
    if (!AppDebouncer.tryAcquire('auth:login')) return;
    if (_loading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showAuthToast(context, "Email dan kata sandi wajib diisi", isError: true);
      return;
    }
    if (!AuthService.isValidEmail(email)) {
      showAuthToast(context, "Format email tidak valid", isError: true);
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
      body: AbsorbPointer(
        absorbing: _loading,
        child: AuthBackground(
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
                          AuthCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const AuthTitle(
                                  title: "Masuk",
                                  subtitle: "Masuk untuk mengelola formulir Anda",
                                ),
                                const SizedBox(height: 24),
                                AuthTextField(
                                  controller: _emailController,
                                  hint: "Email",
                                  label: "Email",
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 17),
                                AuthTextField(
                                  controller: _passwordController,
                                  hint: "Kata Sandi",
                                  label: "Kata Sandi",
                                  icon: Icons.lock_outline,
                                  obscure: true,
                                ),
                                const SizedBox(height: 20),
                                AuthPrimaryButton(
                                  label: "Masuk",
                                  loading: _loading,
                                  onPressed: _login,
                                ),
                                const SizedBox(height: 18),
                                Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      AppRouter.of(context).push(AppPage.forgotPassword);
                                    },
                                    child: const Text(
                                      "Lupa Kata Sandi?",
                                      style: TextStyle(
                                        color: kAuthPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: kFontBold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                AuthInlineLink(
                                  question: "Pengguna baru? ",
                                  link: "Daftar",
                                  onTap: () {
                                    AppRouter.of(context).push(AppPage.register);
                                  },
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
