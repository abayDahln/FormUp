import 'package:flutter/material.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Kartu "Masuk Form": input kode + tombol scan QR
class HomeKerjakanCard extends StatelessWidget {
  final TextEditingController codeController;
  final VoidCallback onStart;
  final VoidCallback onOpenScanner;
  final bool loading;

  const HomeKerjakanCard({
    super.key,
    required this.codeController,
    required this.onStart,
    required this.onOpenScanner,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Masuk Form",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            "Masukkan kode form untuk masuk ke halaman awal form.",
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),

          // ── Row: TextField (kiri) + Scan Button (kanan) ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Field kode form
              Expanded(
                child: TextField(
                  controller: codeController,
                  enabled: !loading,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                  cursorColor: kAuthPrimary,
                  decoration: formUpInputDecoration(
                    labelText: "Kode form",
                    hintText: "Kode",
                    prefixIcon: const Icon(Icons.link, size: 20),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => loading ? null : onStart(),
                ),
              ),

              const SizedBox(width: 8),

              // Tombol scan QR — M3 outlined icon button, selaras tinggi field
              SizedBox(
                height: 56,
                width: 56,
                child: IconButton.outlined(
                  onPressed: loading
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          onOpenScanner();
                        },
                  icon: const Icon(Icons.qr_code_scanner, size: 22),
                  color: kAuthPrimary,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: kFieldBorderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusSm),
                    ),
                  ),
                  tooltip: 'Scan QR',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          AuthPrimaryButton(
            label: "Masuk Form",
            showArrow: false,
            loading: loading,
            onPressed: loading ? null : onStart,
          ),
        ],
      ),
    );
  }
}