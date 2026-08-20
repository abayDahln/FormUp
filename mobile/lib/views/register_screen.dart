import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import '../services/auth_service.dart';
import '../app_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _loading = false;
  bool _accepted = false;

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_loading) return;
    final fullname = _fullnameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (fullname.isEmpty || email.isEmpty || password.isEmpty) {
      showAuthToast(context, "Semua field wajib diisi", isError: true);
      return;
    }
    if (!AuthService.isValidEmail(email)) {
      showAuthToast(context, "Format email tidak valid", isError: true);
      return;
    }
    if (password.length < 8) {
      showAuthToast(context, "Kata sandi minimal 8 karakter", isError: true);
      return;
    }
    if (password != confirm) {
      showAuthToast(context, "Konfirmasi kata sandi tidak cocok", isError: true);
      return;
    }
    if (!_accepted) {
      showAuthToast(context, "Harap setujui Syarat & Ketentuan", isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.register(
        fullname: fullname,
        email: email,
        password: password,
      );
      if (!mounted) return;
      AppRouter.of(context).push(
        AppPage.otp,
        {'email': email, 'fullname': fullname, 'password': password},
      );
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
                        const AuthTitle(
                          title: "Daftar",
                          subtitle: "Buat akun baru untuk memulai",
                        ),
                        const SizedBox(height: 24),
                        AuthCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AuthTextField(
                                controller: _fullnameController,
                                hint: "Nama Lengkap",
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 17),
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
                              const SizedBox(height: 17),
                              AuthTextField(
                                controller: _confirmController,
                                hint: "Konfirmasi Kata Sandi",
                                icon: Icons.lock_outline,
                                obscure: true,
                              ),
                              const SizedBox(height: 16),
                              AuthPrimaryButton(
                                label: "Daftar",
                                loading: _loading,
                                onPressed: _signUp,
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _accepted = !_accepted),
                                    child: Container(
                                      width: 19,
                                      height: 19,
                                      decoration: BoxDecoration(
                                        color: _accepted
                                            ? kAuthPrimary
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          5.5,
                                        ),
                                        border: Border.all(color: kAuthText),
                                      ),
                                      child: _accepted
                                          ? const Icon(
                                              Icons.check,
                                              size: 14,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      "Saya menyetujui Syarat & Ketentuan",
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AuthBottomPill(
                          question: "Sudah punya akun? ",
                          link: "Masuk",
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
      ),
    );
  }
}
