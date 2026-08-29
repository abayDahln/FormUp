import 'dart:io';

import 'package:flutter/foundation.dart';

class NetworkStatus {
  static String _apiBaseUrl = '';
  static bool _offline = false;

  static final ValueNotifier<bool> notifier = ValueNotifier<bool>(false);

  static bool get isOffline => _offline;
  static bool get isOnline => !_offline;

  static void configure(String apiBaseUrl) {
    _apiBaseUrl = apiBaseUrl;
  }

  /// Reset paksa ke online — dipanggil saat login/logout/ganti akun agar
  /// tidak mewarisi flag offline dari akun sebelumnya (penyebab bug lapor).
  static void reset() {
    _offline = false;
    notifier.value = false;
  }

  static Future<void> refresh() async {
    final uri = Uri.tryParse(_apiBaseUrl);
    final host = uri?.host ?? '';
    if (host.isEmpty) {
      markOnline();
      return;
    }
    // Coba koneksi TCP ke host:port API (bukan cuma DNS), agar
    // IP literal 10.0.2.2 tetap tervalidasi dan DNS palsu tidak menipu.
    final port = uri?.hasPort == true ? uri!.port : (uri?.scheme == 'https' ? 443 : 80);
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      socket.destroy();
      markOnline();
    } catch (_) {
      // Fallback DNS bila TCP gagal (mis. firewall blok port)
      try {
        await InternetAddress.lookup(host).timeout(const Duration(seconds: 3));
        // Lookup sukses tapi TCP gagal → anggap online bila host IP literal,
        // jinak untuk emulator 10.0.2.2 yang lookup selalu sukses.
        if (host == '10.0.2.2' || host == 'localhost' || host == '127.0.0.1') {
          markOnline();
        } else {
          markOffline();
        }
      } catch (_) {
        markOffline();
      }
    }
  }

  static void markOffline() {
    if (_offline) return;
    _offline = true;
    notifier.value = true;
  }

  static void markOnline() {
    if (!_offline) return;
    _offline = false;
    notifier.value = false;
  }
}
