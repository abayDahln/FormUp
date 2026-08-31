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
    scaffoldBackgroundColor: kAppBg,
    fontFamily: 'Inter',

    // Card theme M3 — shadow jelas di #F8F9FA
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
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

    // M3 Buttons — https://m3.material.io/components/buttons/overview
    // useMaterial3:true sudah aktif, override hanya warna + shape M3 (20dp)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: kPrimary,
        surfaceTintColor: kPrimary,
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          letterSpacing: 0.1,
        ),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.15),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: kPrimary.withValues(alpha: 0.38),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.38),
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          letterSpacing: 0.1,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary,
        side: const BorderSide(color: Color(0xFF79747E)),
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          letterSpacing: 0.1,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPrimary,
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: kFontBold),
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

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      floatingLabelStyle: const TextStyle(color: kPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      labelStyle: const TextStyle(color: Color(0xFF49454F), fontSize: 14),
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      helperStyle: const TextStyle(color: Color(0xFF49454F), fontSize: 12),
      errorStyle: const TextStyle(color: kDangerColor, fontSize: 12),
      prefixIconColor: const Color(0xFF49454F),
      suffixIconColor: const Color(0xFF49454F),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm), borderSide: const BorderSide(color: kFieldBorderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm), borderSide: const BorderSide(color: kFieldBorderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm), borderSide: const BorderSide(color: kPrimary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm), borderSide: const BorderSide(color: kDangerColor)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm), borderSide: const BorderSide(color: kDangerColor, width: 2)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadiusSm), borderSide: BorderSide(color: kFieldBorderColor.withValues(alpha: 0.38))),
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

/// M3 outlined text field — https://m3.material.io/components/text-fields
/// Varian outlined: label floating, outline 1dp/2dp, support error, prefix/suffix.
/// Dipakai di semua field kecuali SearchBar.
InputDecoration formUpInputDecoration({
  String? hintText,
  String? labelText,
  TextStyle? hintStyle,
  TextStyle? labelStyle,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? helperText,
  String? errorText,
}) {
  // M3 spec: outline radius 4dp, kita pakai kRadiusSm (10) agar selaras sistem.
  const radius = kRadiusSm;
  const outline = kFieldBorderColor; // outline variant
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    helperText: helperText,
    errorText: errorText,
    hintStyle: hintStyle ?? const TextStyle(color: Colors.black38, fontSize: 14),
    labelStyle: labelStyle ?? const TextStyle(color: Color(0xFF49454F), fontSize: 14),
    floatingLabelStyle: const TextStyle(color: kPrimary, fontSize: 14, fontWeight: FontWeight.w500),
    helperStyle: const TextStyle(color: Color(0xFF49454F), fontSize: 12),
    errorStyle: const TextStyle(color: kDangerColor, fontSize: 12),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    prefixIconColor: const Color(0xFF49454F),
    suffixIconColor: const Color(0xFF49454F),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    // M3 outlined borders
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: outline, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: kPrimary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: kDangerColor, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: kDangerColor, width: 2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: outline.withValues(alpha: 0.38)),
    ),
  );
}

/// Shortcut untuk field filled variant bila perlu (mis. dense toolbar)
InputDecoration formUpFilledDecoration({
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  return formUpInputDecoration(hintText: hintText, prefixIcon: prefixIcon, suffixIcon: suffixIcon).copyWith(
    filled: true,
    fillColor: const Color(0xFFF3F6F6),
  );
}

/// Sistem overlay status bar gelap di atas background terang
const List<SystemUiOverlayStyle> kSystemOverlay = [SystemUiOverlayStyle.dark];
