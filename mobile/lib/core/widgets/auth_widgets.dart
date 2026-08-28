import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_toast.dart';

// ===== Design system =====
const kBg = Color(0xFFE2F3F2);
const kPrimary = Color(0xFF2A9D8F);
const kRadius = 20.0;
const kBorderColor = Color(0x1FBDC9C8);
const kPrimarySoft = Color(0xFFE2F3F2);

const kAuthBg = kBg;
const kAuthPrimary = kPrimary;
const kAuthText = Color(0xFF6E7979);
const kAuthFieldFill = Color(0xFFF0F4F4);
const kAuthHint = Color(0xFF4A6363);

const kFontBold = 'PlusJakartaSans';

/// Shadow elevation levels untuk konsistensi di seluruh app
enum ShadowLevel {
  none,
  subtle,    // level 1 - very light
  low,       // level 2 - cards
  medium,    // level 3 - elevated cards, bottom sheets
  high,      // level 4 - modals, FAB
  highest,   // level 5 - dialogs, dropdowns
}

/// Bayangan kartu seragam dengan level elevasi
List<BoxShadow> softShadow({
  double alpha = 0.05,
  Offset offset = const Offset(0, 4),
  double blur = 12,
}) {
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: alpha),
      blurRadius: blur,
      offset: offset,
    ),
  ];
}

/// Bayangan berdasarkan level elevasi
List<BoxShadow> elevationShadow(ShadowLevel level) {
  switch (level) {
    case ShadowLevel.none:
      return [];
    case ShadowLevel.subtle:
      return softShadow(alpha: 0.03, offset: const Offset(0, 1), blur: 3);
    case ShadowLevel.low:
      return softShadow(alpha: 0.05, offset: const Offset(0, 2), blur: 8);
    case ShadowLevel.medium:
      return softShadow(alpha: 0.06, offset: const Offset(0, 4), blur: 12);
    case ShadowLevel.high:
      return softShadow(alpha: 0.08, offset: const Offset(0, 8), blur: 20);
    case ShadowLevel.highest:
      return softShadow(alpha: 0.1, offset: const Offset(0, 12), blur: 28);
  }
}

/// Bayangan untuk tombol (primary, outline, dll)
List<BoxShadow> buttonShadow({
  Color? color,
  ShadowLevel level = ShadowLevel.low,
}) {
  final base = elevationShadow(level);
  if (color == null) return base;
  return [
    BoxShadow(
      color: color.withValues(alpha: 0.25),
      blurRadius: base.first.blurRadius,
      offset: base.first.offset,
    ),
  ];
}

/// Bayangan untuk Card (Material)
List<BoxShadow> cardShadow(ShadowLevel level) {
  return elevationShadow(level);
}

/// Gaya lencana status form
class FormStatusStyle {
  final String label;
  final Color fg;
  final Color bg;
  const FormStatusStyle(this.label, this.fg, this.bg);
}

FormStatusStyle formStatusStyle(String status) {
  switch (status) {
    case 'published':
      return const FormStatusStyle('Terbit', Color(0xFF2E7D32), Color(0xFFE3F4E8));
    case 'draft':
      return const FormStatusStyle('Draf', Color(0xFFB26A00), Color(0xFFFFF3DE));
    default:
      return const FormStatusStyle('Ditutup', Color(0xFFC0392B), Color(0xFFFDE8E6));
  }
}

/// Background mint + gradient
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
                  kAuthPrimary.withValues(alpha: 0.4),
                  const Color(0xFFD9D9D9).withValues(alpha: 0.0),
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

/// Kartu putih seragam
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kBorderColor),
        boxShadow: softShadow(),
      ),
      child: child,
    );
  }
}

/// Judul kartu
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

/// Input field + toggle password
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? label;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.label,
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
    final field = SizedBox(
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

    final label = widget.label;
    if (label == null || label.isEmpty) return field;

    // Label di atas field, gaya sama dengan form maker
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: kAuthPrimary,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

/// Tombol teal (pill atau rx 8)
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool pill;
  final bool showArrow;
  final double? progress;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.pill = false,
    this.showArrow = true,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final height = pill ? 52.0 : 55.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(pill ? 26 : 8),
        boxShadow: [
          BoxShadow(
            color: kAuthPrimary.withValues(alpha: 0.25),
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
            disabledBackgroundColor: kAuthPrimary.withValues(alpha: 0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(pill ? 26 : 8),
            ),
          ),
          child: loading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        "${(progress!.clamp(0.0, 1.0) * 100).round()}%",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                        ),
                      ),
                    ],
                  ],
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

/// Pill navigasi antar screen
/// Baris link inline (pengganti AuthBottomPill saat digabung ke dalam kartu)
class AuthInlineLink extends StatelessWidget {
  final String? question;
  final String link;
  final VoidCallback onTap;

  const AuthInlineLink({
    super.key,
    this.question,
    required this.link,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (question != null)
            Text(
              question!,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              link,
              style: const TextStyle(
                color: kAuthPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kBorderColor),
        boxShadow: softShadow(),
      ),
      child: Center(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (question != null)
                  Text(
                    question!,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 14),
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

/// Input OTP 6 digit
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

/// Wrapper kompatibel: tampil sebagai toast flat colored (varian error/success)
void showAuthToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  showAppToast(context, message,
      type: isError ? ToastType.error : ToastType.success);
}
