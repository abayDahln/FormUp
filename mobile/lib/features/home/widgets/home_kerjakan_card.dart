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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           Text(
            "Masuk Form",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
           Text(
            "Masukkan kode form untuk masuk ke halaman awal form.",
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),

          // Field kode form — tombol scan QR digabung sebagai suffixIcon (M3)
          TextField(
            controller: codeController,
            enabled: !loading,
            style:  TextStyle(color: cs.onSurface, fontSize: 14),
            cursorColor: cs.primary,
            decoration: formUpInputDecoration(
              labelText: "Kode Form",
              hintText: "Kode",
              prefixIcon: const Icon(Icons.link, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner, size: 22),
                color: cs.primary,
                tooltip: 'Scan QR',
                onPressed: loading
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        onOpenScanner();
                      },
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => loading ? null : onStart(),
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