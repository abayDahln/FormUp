import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/ai_chat_icon.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/responsive.dart';

/// Helper Extended FAB adaptif (M3) + margin berlevel seragam.
///
/// Mengacu https://m3.material.io/components/extended-fab/overview :
/// Extended FAB = FAB biasa yang memanjang dengan label teks.
///
/// Aturan yang dipakai:
/// 1. Tinggi & ikon Extended FAB disamakan dengan FAB mobile (68px,
///    ikon 32) — hanya bertambah label di sampingnya.
/// 2. Margin kanan == margin bawah (seragam, tidak besar sebelah).
/// 3. Margin berlevel dalam px, tidak terlalu besar:
///    L1=16, L2=24, L3=32, L4=40, L5=48.
///    - Mobile (lebar <600): selalu L1.
///    - Tablet (600–1200): L1–L2 tergantung ukuran window.
///    - Desktop (≥1200): L2–L5 tergantung lebar (dibatasi tinggi
///      agar window pendek tidak dapat margin besar).

/// Tinggi FAB tambah — lingkaran mobile maupun extended disamakan.
const double kAddFabHeight = 68;

/// Ukuran ikon FAB tambah — lingkaran mobile maupun extended disamakan.
const double kAddFabIconSize = 32;

/// Margin tepi (px) per level.
double _marginForLevel(int level) {
  switch (level) {
    case 2:
      return 24;
    case 3:
      return 32;
    case 4:
      return 40;
    case 5:
      return 48;
    default:
      return 16;
  }
}

/// Level margin 1–5 dari ukuran window saat ini.
int fabMarginLevel(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final w = size.width;
  final h = size.height;
  // Mobile: selalu level 1.
  if (w < kTabletBreakpoint) return 1;
  // Tablet: level 1–2 — naik ke 2 bila window cukup besar
  // (lebar setidaknya expanded atau tinggi setidaknya 900).
  if (w < kDesktopBreakpoint) {
    return (w >= kExpandedBreakpoint || h >= 900) ? 2 : 1;
  }
  // Desktop: level 2–5 — naik tiap ~250px lebar di atas 1200,
  // dibatasi tinggi window agar tidak kebesaran di layar pendek.
  var level = 2 + ((w - kDesktopBreakpoint) / 250).floor();
  level = level.clamp(2, 5);
  final maxByHeight = h < 700 ? 3 : h < 800 ? 4 : 5;
  return level.clamp(2, maxByHeight);
}

/// Margin tepi total (px) kanan == bawah untuk window saat ini.
double fabEdgeMargin(BuildContext context) =>
    _marginForLevel(fabMarginLevel(context));

/// Padding TAMBAHAN seragam kanan+bawah di atas margin bawaan Scaffold
/// (16px). Nol di level 1 sehingga phone/tablet kecil render identik.
EdgeInsets fabPad(BuildContext context) {
  final extra = fabEdgeMargin(context) - 16;
  if (extra <= 0) return EdgeInsets.zero;
  return EdgeInsets.only(right: extra, bottom: extra);
}

/// Extended FAB M3 untuk layar besar (icon + label), meniru proporsi
/// https://m3.material.io/components/extended-fab/overview :
/// ikon & teks reguler (tidak tebal), teks font Inter. Tinggi 68 & ikon 32
/// disamakan dengan FAB lingkaran mobile — hanya bertambah label.
/// Warna dipertahankan seperti FAB mobile (kPrimary + putih).
Widget buildExtendedAddFab({
  required Key? key,
  required VoidCallback? onPressed,
  required String label,
  String? tooltip,
  Object? heroTag,
}) {
  return SizedBox(
    height: kAddFabHeight,
    child: FloatingActionButton.extended(
      key: key,
      heroTag: heroTag,
      onPressed: onPressed,
      tooltip: tooltip,
      icon: const Icon(Icons.add, size: kAddFabIconSize),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          fontFamily: 'Inter',
        ),
      ),
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}

/// FAB AI Form Agent 56px (FAB standar M3) — pendamping FAB tambah 68px:
/// jelas lebih besar dari FAB small (40px) agar tidak terlihat kecil di
/// desktop/Windows, namun tetap sekunder terhadap tombol tambah.
/// Satu definisi agar ukuran tombol AI identik di semua layar edit form
/// (builder desktop, tab phone, panel soal).
Widget buildAiFab({
  required Key? key,
  required VoidCallback? onPressed,
  required Color backgroundColor,
  required Color foregroundColor,
  String? tooltip,
  Object? heroTag,
}) {
  return SizedBox(
    width: 56,
    height: 56,
    child: FloatingActionButton(
      key: key,
      heroTag: heroTag,
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: AiChatIcon(size: 26, color: foregroundColor, filled: true),
    ),
  );
}

/// FAB tambah lingkaran 68px — dipakai phone agar render identik.
Widget buildCircleAddFab({
  required Key? key,
  required VoidCallback? onPressed,
  String? tooltip,
  Object? heroTag,
}) {
  return SizedBox(
    width: 68,
    height: kAddFabHeight,
    child: FloatingActionButton(
      key: key,
      heroTag: heroTag,
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.add, size: kAddFabIconSize),
    ),
  );
}
