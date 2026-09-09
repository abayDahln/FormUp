import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pilihan tema aplikasi: terang, gelap, atau ikuti sistem.
enum AppThemeChoice { light, dark, system }

extension AppThemeChoiceExt on AppThemeChoice {
  String get label => switch (this) {
        AppThemeChoice.light => 'Terang',
        AppThemeChoice.dark => 'Gelap',
        AppThemeChoice.system => 'Ikuti sistem',
      };

  IconData get icon => switch (this) {
        AppThemeChoice.light => Icons.light_mode_outlined,
        AppThemeChoice.dark => Icons.dark_mode_outlined,
        AppThemeChoice.system => Icons.settings_suggest_outlined,
      };

  ThemeMode get mode => switch (this) {
        AppThemeChoice.light => ThemeMode.light,
        AppThemeChoice.dark => ThemeMode.dark,
        AppThemeChoice.system => ThemeMode.system,
      };

  String get storageValue => name;
}

/// Pengatur tema global — satu instance untuk seluruh aplikasi.
///
/// - [load] dipanggil sekali sebelum runApp agar tema tersimpan langsung
///   dipakai (tanpa kedip).
/// - [setChoice] menyimpan pilihan (persist) + notify agar MaterialApp
///   rebuild dengan ThemeMode baru.
/// - [isDarkNow] dibaca helper tanpa context (mis. InputDecoration) —
///   aman karena widget selalu rebuild saat tema berubah.
class ThemeController extends ValueNotifier<AppThemeChoice> {
  static const _storageKey = 'app_theme_choice';
  static final ThemeController instance = ThemeController._();

  ThemeController._() : super(AppThemeChoice.system) {
    // Ikuti perubahan tema sistem secara live selama pilihan = system,
    // agar helper tanpa-context (isDarkNow) ikut refresh.
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        () {
      if (value == AppThemeChoice.system) notifyListeners();
    };
  }

  bool _loaded = false;

  /// True bila tema efektif saat ini gelap. Sebelum [load], ikut sistem
  /// via brightness platform — fallback terang bila tak diketahui.
  bool get isDarkNow {
    switch (value) {
      case AppThemeChoice.light:
        return false;
      case AppThemeChoice.dark:
        return true;
      case AppThemeChoice.system:
        return WidgetsBinding
                .instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        value = AppThemeChoice.values.firstWhere(
          (e) => e.storageValue == raw,
          orElse: () => AppThemeChoice.system,
        );
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> setChoice(AppThemeChoice choice) async {
    value = choice;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, choice.storageValue);
    } catch (_) {}
  }
}
