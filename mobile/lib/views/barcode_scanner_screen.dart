import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'auth_widgets.dart';
import '../app_router.dart';

/// Screen scan QR/barcode untuk masuk form.
/// Hanya menerima link format https://formup.my.id/f/{formLink}
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  static final _validUrl = RegExp(
    r'^https://formup\.my\.id/f/(.+)$',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Ekstrak formLink dari URL. Null bila format tidak sesuai.
  String? _extractFormLink(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    // Bersihkan trailing slash (mis. /f/kode/)
    final m = _validUrl.firstMatch(trimmed);
    if (m == null) return null;
    final link = m.group(1)!.replaceAll(RegExp(r'/+$'), '');
    return link.isEmpty ? null : link;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    final formLink = _extractFormLink(raw);
    if (formLink == null) return; // link tidak valid, biarkan tetap scan

    _handled = true;
    _controller.stop();

    // Langsung arahkan ke Screen Awal Form milik form tsb
    AppRouter.of(context).push(AppPage.formStart, {'formLink': formLink});
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "Scan Kode",
          style: TextStyle(fontFamily: kFontBold, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => const Center(
              child: Text(
                "Tidak dapat mengakses kamera. Pastikan izin kamera diberikan.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          // Overlay frame pemindai
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Arahkan kamera ke QR/barcode berisi link form\nformat: https://formup.my.id/f/{kode}",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}