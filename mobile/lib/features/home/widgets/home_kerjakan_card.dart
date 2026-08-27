import 'package:flutter/material.dart';
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
                  style: const TextStyle(color: Colors.black87),
                  cursorColor: kAuthPrimary,
                  decoration: InputDecoration(
                    hintText: "Kode form",
                    hintStyle: const TextStyle(color: kAuthText),
                    prefixIcon: const Icon(Icons.link, color: kAuthText),
                    filled: true,
                    fillColor: const Color(0xFFF0F4F4),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kAuthText),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kAuthText),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: kAuthPrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => loading ? null : onStart(),
                ),
              ),

              const SizedBox(width: 8),

              // Tombol scan QR (warna sama dengan field, tidak kontras)
              SizedBox(
                height: 48,
                width: 48,
                child: Material(
                  color: const Color(0xFFF0F4F4), 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: kAuthText),
                  ),
                  child: InkWell( 
                    onTap: loading
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            onOpenScanner();
                          },
                    borderRadius: BorderRadius.circular(8),
                    
                    child: const Icon(
                      Icons.qr_code_scanner,
                      color: kAuthPrimary, // Warna icon tetap primary
                    ),
                  ),
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