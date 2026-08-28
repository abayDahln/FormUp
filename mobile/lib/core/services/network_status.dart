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

  static Future<void> refresh() async {
    final host = Uri.tryParse(_apiBaseUrl)?.host ?? '';
    if (host.isEmpty) {
      markOnline();
      return;
    }

    try {
      await InternetAddress.lookup(host).timeout(
        const Duration(seconds: 3),
      );
      markOnline();
    } catch (_) {
      markOffline();
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
