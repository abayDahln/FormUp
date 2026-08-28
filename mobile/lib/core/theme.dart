import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

// ---------------------------------------------------------------------------
// Design tokens — sumber kebenaran tunggal untuk UI FormUp.
// Komponen baru wajib memakai token ini, bukan nilai literal.
// ---------------------------------------------------------------------------

/// Warna semantik status (dipakai lintasan badge/skor/error)
const Color kSuccessColor = Color(0xFF2E7D32);
const Color kWarningColor = Color(0xFFB26A00);
const Color kDangerColor = Color(0xFFC0392B);
const Color kInfoColor = Color(0xFF607D8B);

/// Radius baku
const double kRadiusXl = 20; // card utama / settings card
const double kRadiusLg = 16; // card list & summary
const double kRadiusMd = 12; // ikon chip & elemen sekunder
const double kRadiusSm = 10; // opsi & baris jawaban

/// Border input standar (meniru gaya field auth)
const Color kFieldBorderColor = Color(0xFF6E7979);

/// TextStyle judul bold agar tidak perlu tulis fontFamily manual
TextStyle kTitleStyle({double fontSize = 22, Color color = Colors.black87}) =>
    TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      fontFamily: kFontBold,
      color: color,
    );

/// ThemeData aplikasi — komponen Material 3 otomatis konsisten.
ThemeData buildFormUpTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kPrimary);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    fontFamily: 'Inter',

    // Card theme dengan shadow konsisten
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      margin: EdgeInsets.zero,
    ),

    // AppBar putih dengan garis bawah — gaya semua screen
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: Color(0xCCBDC9C8))),
      iconTheme: IconThemeData(color: Colors.black87),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: kFontBold,
        color: Colors.black87,
      ),
    ),

    // Dialog putih rounded dengan shadow
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(kRadiusLg)),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: kFontBold,
        color: Colors.black87,
      ),
      contentTextStyle: const TextStyle(fontSize: 14, color: Colors.black54),
    ),

    // Bottom sheet theme dengan shadow
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      modalBackgroundColor: Colors.white,
    ),

    // Tombol
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
        ),
        elevation: 0,
        shadowColor: kPrimary.withValues(alpha: 0.25),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary,
        side: const BorderSide(color: kPrimary),
        minimumSize: const Size(64, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
        ),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    // Ikon button tonal (mis. navigasi halaman admin)
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimarySoft,
        shape: const StadiumBorder(),
        elevation: 0,
      ),
    ),

    dividerTheme: const DividerThemeData(color: Colors.black12),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: kPrimary,
      unselectedItemColor: Colors.grey,
      elevation: 8,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? kPrimary : null),
    ),

    // Floating action button dengan shadow
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      elevation: 4,
      focusElevation: 6,
      hoverElevation: 6,
      highlightElevation: 8,
      shape: const CircleBorder(),
    ),

    // Menu/theme untuk dropdown, popup menu
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
    ),

    // Tooltip theme
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(kRadiusSm),
        boxShadow: elevationShadow(ShadowLevel.high),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    // SnackBar theme
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.black87,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      elevation: 6,
    ),
  );
}

/// Style InputDecoration dasar bergaya auth (filled putih + outline).
/// Dipakai lewat copyWith karena hint/prefix tiap field berbeda.
InputDecoration formUpInputDecoration({
  String? hintText,
  TextStyle? hintStyle,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: hintStyle ?? const TextStyle(color: Colors.black38, fontSize: 14),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding:
        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadiusSm),
      borderSide: const BorderSide(color: kFieldBorderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadiusSm),
      borderSide: const BorderSide(color: kPrimary),
    ),
  );
}

/// Sistem overlay status bar gelap di atas background terang
const List<SystemUiOverlayStyle> kSystemOverlay = [SystemUiOverlayStyle.dark];
