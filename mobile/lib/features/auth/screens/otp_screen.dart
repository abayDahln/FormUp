import 'dart:async';
import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/router/app_router.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String? fullname;
  final String? password;

  const OtpScreen({
    super.key,
    required this.email,
    this.fullname,
    this.password,
  });

  bool get isRegister => fullname != null;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _loading = false;
  int _cooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_cooldown <= 1) {
          t.cancel();
          _cooldown = 0;
        } else {
          _cooldown--;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_loading) return;
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length < 6) {
      showAuthToast(context, "Masukkan kode OTP 6 digit", isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      if (widget.isRegister) {
        final result = await AuthService.verifyRegistration(
          fullname: widget.fullname!,
          email: widget.email,
          password: widget.password!,
          otp: otp,
        );
        if (!mounted) return;
        final displayName = result.fullname.isEmpty
            ? result.username
            : result.fullname;
        AppRouter.of(context).goHome(displayName);
      } else {
        if (!mounted) return;
        AppRouter.of(context).push(
          AppPage.resetPassword,
          {'email': widget.email, 'otp': otp},
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) {
      showAuthToast(context, "Tunggu $_cooldown detik untuk mengirim ulang", isError: true);
      return;
    }
    try {
      if (widget.isRegister) {
        await AuthService.register(
          fullname: widget.fullname!,
          email: widget.email,
          password: widget.password!,
        );
      } else {
        await AuthService.forgotPassword(widget.email);
      }
      if (!mounted) return;
      _startCooldown();
      showAuthToast(context, "Kode OTP telah dikirim ulang ke email");
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
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
                                 title: "Verifikasi",
                                 subtitle: "Verifikasi email Anda",
                               ),
                               const SizedBox(height: 24),
                              Text(
                                "Kode OTP telah dikirim ke\n${widget.email}",
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 28),
                              OtpField(controller: _otpController),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.center,
                                child: GestureDetector(
                                  onTap: _resend,
                                  child: Text(
                                    _cooldown > 0
                                        ? "kirim ulang ($_cooldown s)"
                                        : "kirim ulang",
                                    style: const TextStyle(
                                      color: kAuthPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: kFontBold,
                                      decoration: TextDecoration.underline,
                                      decorationColor: kAuthPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              AuthPrimaryButton(
                                label: "Verifikasi",
                                pill: true,
                                loading: _loading,
                                onPressed: _verify,
                              ),
                              const SizedBox(height: 20),
                              AuthInlineLink(
                                link: "Kembali ke Masuk",
                                onTap: () =>
                                    AppRouter.of(context).resetToLogin(),
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

