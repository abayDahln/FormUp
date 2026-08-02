import 'package:flutter/material.dart';

// Warna dari ui_screen/*.svg
const kAuthBg = Color(0xFFE1F9F4);
const kAuthPrimary = Color(0xFF018081);
const kAuthText = Color(0xFF6E7979);
const kAuthFieldFill = Color(0xFFF0F4F4);
const kAuthHint = Color(0xFF4A6363);

// Font: Inter untuk teks biasa, Plus Jakarta Sans untuk teks tebal.
const kFontBold = 'PlusJakartaSans';

/// Latar belakang: warna hijau mint + ellipse gradient di kiri atas.
class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Container(width: size.width, height: size.height, color: kAuthBg),
        Positioned(
          top: -150,
          left: -130,
          child: Container(
            width: size.width * 1.2,
            height: size.width * 1.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomRight,
                colors: [
                  kAuthPrimary.withOpacity(0.4),
                  const Color(0xFFD9D9D9).withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Kartu putih transparan (rx 34) dengan border + bayangan halus.
class AuthCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const AuthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xCCBDC9C8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(2, 2),
            blurRadius: 2.5,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Judul besar di atas kartu.
class AuthTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AuthTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontFamily: kFontBold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ],
      ],
    );
  }
}

/// Input field bergaris (rx 7.5) dengan ikon; ada toggle mata jika password.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscure;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextField(
        controller: widget.controller,
        obscureText: _obscure,
        keyboardType: widget.keyboardType,
        style: const TextStyle(color: Colors.black87),
        cursorColor: kAuthPrimary,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: kAuthText),
          prefixIcon: Icon(widget.icon, color: kAuthText),
          suffixIcon: widget.obscure
              ? IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: kAuthText,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7.5),
            borderSide: const BorderSide(color: kAuthText),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7.5),
            borderSide: const BorderSide(color: kAuthText),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7.5),
            borderSide: const BorderSide(color: kAuthPrimary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Tombol teal: rx 8 (login/register) atau rx 26 pill (forgot/verify/reset).
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool pill;
  final bool showArrow;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.pill = false,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final height = pill ? 52.0 : 55.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(pill ? 26 : 8),
        boxShadow: [
          BoxShadow(
            color: kAuthPrimary.withOpacity(0.25),
            offset: const Offset(0, 4),
            blurRadius: 7.5,
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: kAuthPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            disabledBackgroundColor: kAuthPrimary.withOpacity(0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(pill ? 26 : 8),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                      ),
                    ),
                    if (showArrow) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Pill bawah transparan untuk navigasi antar screen auth.
class AuthBottomPill extends StatelessWidget {
  final String? question;
  final String link;
  final VoidCallback onTap;

  const AuthBottomPill({
    super.key,
    required this.link,
    required this.onTap,
    this.question,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xCCBDC9C8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(2, 2),
            blurRadius: 2.5,
          ),
        ],
      ),
      child: Center(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (question != null)
                  Text(
                    question!,
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                Text(
                  link,
                  style: const TextStyle(
                    color: kAuthPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    decoration: TextDecoration.underline,
                    decorationColor: kAuthPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 6 kotak OTP 43x47; input lewat TextField transparan.
class OtpField extends StatefulWidget {
  final TextEditingController controller;

  const OtpField({super.key, required this.controller});

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 47,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                showCursor: false,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(6, (i) {
              final char = widget.controller.text.length > i
                  ? widget.controller.text[i]
                  : '';
              return Expanded(
                child: Container(
                  height: 47,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kAuthFieldFill,
                    borderRadius: BorderRadius.circular(7.5),
                    border: Border.all(
                      color:
                          i == widget.controller.text.length &&
                              _focusNode.hasFocus
                          ? kAuthPrimary
                          : kAuthText,
                      width:
                          i == widget.controller.text.length &&
                              _focusNode.hasFocus
                          ? 1.5
                          : 1,
                    ),
                  ),
                  child: Text(
                    char,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontFamily: kFontBold,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Toast custom (bukan SnackBar bawaan Flutter): pill putih float di bawah, font Inter.
void showAuthToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 22,
      right: 22,
      bottom: MediaQuery.of(context).viewPadding.bottom + 16,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xCCBDC9C8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? const Color(0xFFC0392B) : kAuthPrimary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 2500), () {
    if (entry.mounted) entry.remove();
  });
}
