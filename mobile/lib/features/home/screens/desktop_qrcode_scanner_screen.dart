import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/app_toast.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:zxing2/qrcode.dart';

/// Layar pindai QR khusus desktop (Windows/macOS/Linux).
///
/// `mobile_scanner` tidak mendukung desktop, jadi alurnya: preview kamera
/// (plugin `camera`) → tombol "Ambil & Pindai" memotret → frame di-decode
/// dengan `zxing2` (Dart murni). Bila kamera tidak ada/gagal, fallback:
/// pilih file gambar QR dari disk, atau isi kode manual di Beranda.
/// Alur setelah QR terbaca sama persis dengan layar mobile.
class DesktopQrcodeScannerScreen extends StatefulWidget {
  const DesktopQrcodeScannerScreen({super.key});

  @override
  State<DesktopQrcodeScannerScreen> createState() =>
      _DesktopQrcodeScannerScreenState();
}

class _DesktopQrcodeScannerScreenState
    extends State<DesktopQrcodeScannerScreen> {
  CameraController? _camera;
  bool _cameraReady = false;
  bool _cameraFailed = false;
  bool _busy = false;
  String? _errorMessage;
  Timer? _scanTimer;
  bool _autoScanning = false;

  static final _validUrl = RegExp(
    r'^https://formup\.my\.id/f/(.+)$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _stopAutoScan();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty || !mounted) {
        if (mounted) setState(() => _cameraFailed = true);
        return;
      }
      // Windows laptop/PC: utamakan kamera depan, fallback ke pertama
      CameraDescription selected = cameras.first;
      try {
        selected = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
      } catch (_) {}
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _cameraReady = true;
      });
      _startAutoScan();
    } catch (_) {
      if (mounted) setState(() => _cameraFailed = true);
    }
  }

  void _startAutoScan() {
    _scanTimer?.cancel();
    // Mobile langsung terbaca tanpa tombol: Windows juga otomatis tiap 900ms
    _scanTimer = Timer.periodic(const Duration(milliseconds: 900), (_) async {
      if (!mounted || !_cameraReady || _busy || _autoScanning) return;
      final cam = _camera;
      if (cam == null || !cam.value.isInitialized) return;
      _autoScanning = true;
      try {
        final photo = await cam.takePicture();
        final bytes = await photo.readAsBytes();
        // Hapus file temp segera
        try {
          await photo.readAsBytes().then((_) {});
        } catch (_) {}
        final text = await _decodeQrBytes(bytes);
        if (text != null && mounted && !_busy) {
          _scanTimer?.cancel();
          await _handleRawText(text);
        }
      } catch (_) {
        // diam — coba lagi di tick berikutnya
      } finally {
        _autoScanning = false;
      }
    });
  }

  void _stopAutoScan() {
    _scanTimer?.cancel();
    _scanTimer = null;
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

  /// Decode QR dari bytes gambar (foto kamera / file). Null bila tak terbaca.
  Future<String?> _decodeQrBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1280,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      codec.dispose();
      if (byteData == null) return null;
      final rgba = byteData.buffer.asUint8List();
      final count = image.width * image.height;
      final pixels = Int32List(count);
      for (var i = 0; i < count; i++) {
        final r = rgba[i * 4];
        final g = rgba[i * 4 + 1];
        final b = rgba[i * 4 + 2];
        pixels[i] = 0xFF000000 | (r << 16) | (g << 8) | b;
      }
      final source = RGBLuminanceSource(image.width, image.height, pixels);
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      final result = QRCodeReader().decode(bitmap);
      final text = result.text.trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleRawText(String? raw) async {
    final formLink = _extractFormLink(raw);
    if (raw != null && raw.trim().isNotEmpty && formLink == null) {
      _fail('QR tidak valid.\nPastikan kode berisi link FormUp.');
      return;
    }
    if (formLink == null) {
      _fail('QR tidak terbaca. Coba lagi atau pilih file gambar.');
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final info = await PublicFormService.getFormInfo(formLink, refresh: true);
      if (!mounted) return;
      if (info.isOwner) {
        _fail('Anda tidak dapat mengisi form yang Anda buat sendiri.');
        return;
      }
      AppRouter.of(context).replaceTop(
        AppPage.formStart,
        {'formLink': formLink},
      );
    } catch (e) {
      if (!mounted) return;
      _fail(AuthService.formLookupErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
    showAppToast(context, message, type: ToastType.error, title: 'Gagal');
  }

  // Future<void> _captureAndDecode() async {
  //   final camera = _camera;
  //   if (camera == null || !camera.value.isInitialized || _busy) return;
  //   setState(() {
  //     _busy = true;
  //     _errorMessage = null;
  //   });
  //   try {
  //     final photo = await camera.takePicture();
  //     final bytes = await photo.readAsBytes();
  //     if (!mounted) return;
  //     setState(() => _busy = false);
  //     await _handleRawText(await _decodeQrBytes(bytes));
  //   } catch (_) {
  //     if (!mounted) return;
  //     setState(() => _busy = false);
  //     _fail('Gagal mengambil foto. Coba lagi atau pilih file gambar.');
  //   }
  // }

  Future<void> _pickFileAndDecode() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final bytes = picked?.files.singleOrNull?.bytes;
      if (!mounted) return;
      setState(() => _busy = false);
      if (bytes == null) return;
      await _handleRawText(await _decodeQrBytes(bytes));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _fail('Gagal membaca file gambar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          onPressed: () => AppRouter.of(context).pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildPreview(cs)),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC0392B).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFC0392B).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_busy) ...[
                  const Center(child: AppLoadingIndicator(color: Colors.white)),
                  const SizedBox(height: 12),
                ],
                // AuthPrimaryButton(
                //   label: 'Ambil & Pindai',
                //   pill: true,
                //   loading: _busy,
                //   onPressed: (_cameraReady && !_busy)
                //       ? _captureAndDecode
                //       : null,
                // ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickFileAndDecode,
                  icon: const Icon(Icons.image_outlined,
                      color: Colors.white, size: 18),
                  label: const Text('Pilih dari File',
                      style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _cameraReady && !_cameraFailed
                      ? 'Arahkan QR ke dalam kotak — otomatis terbaca\nformat: https://formup.my.id/f/{kode} / Pilih dari File'
                      : 'Arahkan QR ke dalam kotak — otomatis terbaca\nformat: https://formup.my.id/f/{kode}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (_cameraReady && !_busy) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white54),
                      ),
                      SizedBox(width: 6),
                      Text('Mencari QR otomatis...', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(ColorScheme cs) {
    final camera = _camera;
    if (_cameraFailed || (camera == null && !_cameraReady)) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _cameraReady
                  ? ''
                  : 'Tidak dapat mengakses kamera.\nGunakan tombol "Pilih dari File" di bawah\natau isi kode manual di Beranda.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
      );
    }
    if (!_cameraReady || camera == null) {
      return const Center(child: AppLoadingIndicator(color: Colors.white));
    }
    // Full-screen 16:9 agar tidak gepeng (stretch). Box scan diperbesar agar QR mudah terbaca.
    final previewSize = camera.value.previewSize;
    final isFront = camera.description.lensDirection == CameraLensDirection.front;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // FittedBox cover: preview mengisi 16:9 tanpa gepeng
            if (previewSize != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: previewSize.width,
                  height: previewSize.height,
                  child: CameraPreview(camera),
                ),
              )
            else
              CameraPreview(camera),
            // Overlay gelap di luar kotak scan agar fokus ke QR
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.45),
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 360,
                      height: 360,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  border: Border.all(color: cs.surface, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            // Hint kamera depan (mirrored) — koreksi decode tetap via bytes foto asli
            if (isFront)
              const Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Text(
                  'Kamera depan',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
