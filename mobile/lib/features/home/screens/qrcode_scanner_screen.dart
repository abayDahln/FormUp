import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/router/app_router.dart';

class QrcodeScannerScreen extends StatefulWidget {
  const QrcodeScannerScreen({super.key});

  @override
  State<QrcodeScannerScreen> createState() => _QrcodeScannerScreenState();
}

class _QrcodeScannerScreenState extends State<QrcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;
  String? _errorMessage;

  static final _validUrl = RegExp(
    r'^https://formup\.my\.id/f/(.+)$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _isProcessing = false;
    _errorMessage = null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _extractFormLink(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    final m = _validUrl.firstMatch(trimmed);
    if (m != null) {
      final link = m.group(1)!.replaceAll(RegExp(r'/+$'), '');
      return link.isEmpty ? null : link;
    }
    if (RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  void _showErrorToast(String message) {
    _controller.stop();
    setState(() => _errorMessage = message);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Scan Ulang',
          textColor: Colors.white,
          onPressed: _rescan,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _rescan() async {
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    setState(() {
      _errorMessage = null;
      _isProcessing = false;
    });
    try {
      await _controller.start();
    } catch (_) {
      if (!mounted) return;
      _showErrorToast('Tidak dapat mengaktifkan kamera. Periksa izin kamera.');
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _errorMessage != null) return;

    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    final formLink = _extractFormLink(raw);

    if (raw != null && raw.trim().isNotEmpty && formLink == null) {
      _showErrorToast('QR tidak valid.\nPastikan kode berisi link FormUp.');
      return;
    }

    if (formLink == null) return;

    await _controller.stop();
    if (!mounted) return;

    setState(() => _isProcessing = true);

    try {
      final info = await PublicFormService.getFormInfo(formLink);
      if (!mounted) return;

      if (info.isOwner) {
        setState(() => _isProcessing = false);
        _showErrorToast('Anda tidak dapat mengisi form yang Anda buat sendiri.');
        return;
      }

      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      AppRouter.of(context).replaceTop(
        AppPage.formStart,
        {'formLink': formLink},
      );
      
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showErrorToast(AuthService.errorMessage(e));
    }
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
          'Scan Kode',
          style: TextStyle(fontFamily: kFontBold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Kembali ke beranda atau halaman sebelumnya
            ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
            AppRouter.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => const Center(
              child: Text(
                'Tidak dapat mengakses kamera.\nPastikan izin kamera diberikan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
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
                'Arahkan kamera ke QR code berisi link form\nformat: https://formup.my.id/f/{kode}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: AppLoadingIndicator(color: kAuthPrimary),
              ),
            ),
        ],
      ),
    );
  }
}
