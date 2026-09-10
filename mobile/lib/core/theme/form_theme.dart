import 'package:flutter/material.dart';

/// Tema dinamis per-form (paritas web `--form-primary` / `--form-bg`):
/// dari SATU warna primer, bangun palet M3 lengkap via
/// `ColorScheme.fromSeed` untuk terang & gelap, lalu:
///
/// - `primary`/`onPrimary` dikunci ke warna persis pilihan user (fromSeed
///   menggeser primer — trik yang sama dipakai tema app).
/// - `surface` = background persis pilihan user (tanpa blend).
/// - Guard kontras: bila `onSurface` tak terbaca di atas background
///   (kontras < 3.0), ganti hitam/putih berdasar luminance.
/// - Kartu & varian (`surfaceContainer*`, `primaryContainer`, dst) tetap
///   dari palet seed agar harmonis dan menonjol dari background.
class FormTheme {
  final Color? primary;
  final Color? background;

  const FormTheme({this.primary, this.background});

  bool get hasCustom => primary != null || background != null;

  static Color? parseHex(String? hex) {
    if (hex == null || !hex.startsWith('#') || hex.length != 7) return null;
    try {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return null;
    }
  }

  static FormTheme parse({String? primaryHex, String? backgroundHex}) {
    return FormTheme(
      primary: parseHex(primaryHex),
      background: parseHex(backgroundHex),
    );
  }

  static FormTheme fromSettings(Map<String, dynamic>? settings) {
    if (settings == null) return const FormTheme();
    return parse(
      primaryHex: settings['themePrimaryColor'] as String?,
      backgroundHex: settings['themeBackgroundColor'] as String?,
    );
  }

  /// Teks di atas warna primer (putih/hitam berdasar luminance).
  static Color onPrimaryFor(Color primary) =>
      primary.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  /// Kontras relatif WCAG (tanpa gamma penuh — cukup untuk guard).
  static double _contrast(Color a, Color b) {
    final l1 = a.computeLuminance() + 0.05;
    final l2 = b.computeLuminance() + 0.05;
    return l1 > l2 ? l1 / l2 : l2 / l1;
  }

  /// Bangun skema dinamis lengkap dari primer form + brightness aktif.
  static ColorScheme buildScheme(ColorScheme base, FormTheme theme) {
    final seed = theme.primary ?? base.primary;
    var scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: base.brightness,
    );
    // Kunci primer ke warna persis pilihan user.
    if (theme.primary != null) {
      scheme = scheme.copyWith(
        primary: theme.primary,
        onPrimary: onPrimaryFor(theme.primary!),
      );
    }
    final bg = theme.background;
    if (bg != null) {
      var onSurface = scheme.onSurface;
      // Guard kontras: teks tak terbaca di atas bg pilihan user.
      if (_contrast(onSurface, bg) < 3.0) {
        onSurface =
            bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
      }
      var onVariant = scheme.onSurfaceVariant;
      if (_contrast(onVariant, bg) < 2.2) {
        onVariant = onSurface.withValues(alpha: 0.75);
      }
      scheme = scheme.copyWith(
        surface: bg,
        onSurface: onSurface,
        onSurfaceVariant: onVariant,
      );
    }
    return scheme;
  }
}

/// Menerapkan tema dinamis per-form ke subtree: skema warna lengkap +
/// component themes kunci (tombol, FAB, switch, checkbox, slider,
/// progress, chip, dialog) dibangun ulang dari skema baru — `copyWith`
/// colorScheme saja TIDAK cukup karena nilai lama sudah dipanggang.
///
/// Catatan: hanya dipakai di layar runner (scope yang disetujui).
class FormThemeScope extends StatelessWidget {
  final FormTheme theme;
  final Widget child;

  const FormThemeScope({
    super.key,
    required this.theme,
    required this.child,
  });

  ThemeData _retint(ThemeData base, ColorScheme scheme) {
    final primary = scheme.primary;
    final onPrimary = scheme.onPrimary;
    return base.copyWith(
      colorScheme: scheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: primary),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onPrimary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : null,
        ),
        checkColor: WidgetStatePropertyAll(onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : null,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: primary,
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: scheme.primaryContainer,
        secondarySelectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!theme.hasCustom) return child;
    final base = Theme.of(context);
    final scheme = FormTheme.buildScheme(base.colorScheme, theme);
    Widget themed =
        Theme(data: _retint(base, scheme), child: child);
    final bg = theme.background;
    if (bg != null) {
      // Background persis pilihan user (skema sudah memuatnya di surface,
      // Container memastikan area non-surface ikut terwarnai).
      themed = Container(color: bg, child: themed);
    }
    return themed;
  }
}
