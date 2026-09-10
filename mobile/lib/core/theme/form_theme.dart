import 'package:flutter/material.dart';

/// Tema per-form (paritas web `--form-primary` / `--form-bg`), adaptif
/// mode terang & gelap:
/// - Primer dipakai mentah untuk aksen (tombol, slider, indikator).
/// - Background di-blend ke surface tema aktif (35%) agar warna terang
///   tidak menyilaukan di dark mode dan warna gelap tidak menenggelamkan
///   konten di light mode.
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

  /// Background custom yang sudah dijinakkan ke tema aktif.
  static Color adaptedBackground(ColorScheme base, Color custom) =>
      Color.lerp(base.surface, custom, 0.35) ?? base.surface;

  static Color adaptedPrimaryContainer(ColorScheme base, Color primary) =>
      Color.lerp(base.surface, primary, 0.16) ?? base.primaryContainer;
}

/// Menerapkan tema per-form ke subtree: override `colorScheme.primary`
/// (+ onPrimary/primaryContainer turunan) sehingga SEMUA widget yang
/// memakai `cs.primary` otomatis ikut — plus background adaptif.
class FormThemeScope extends StatelessWidget {
  final FormTheme theme;
  final Widget child;

  const FormThemeScope({
    super.key,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!theme.hasCustom) return child;
    final base = Theme.of(context);
    final cs = base.colorScheme;
    final primary = theme.primary ?? cs.primary;
    final scheme = cs.copyWith(
      primary: primary,
      onPrimary: FormTheme.onPrimaryFor(primary),
      primaryContainer: theme.primary != null
          ? FormTheme.adaptedPrimaryContainer(cs, primary)
          : cs.primaryContainer,
      onPrimaryContainer: primary,
    );
    Widget themed = Theme(data: base.copyWith(colorScheme: scheme), child: child);
    final bg = theme.background;
    if (bg != null) {
      themed = Container(
        color: FormTheme.adaptedBackground(cs, bg),
        child: themed,
      );
    }
    return themed;
  }
}
