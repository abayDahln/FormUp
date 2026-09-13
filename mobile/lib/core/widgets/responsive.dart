import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double kTabletBreakpoint = 600;
const double kExpandedBreakpoint = 840;
const double kDesktopBreakpoint = 1200;

/// Layar ekstra-lebar (1080p ke atas, mis. 1920×1080): grid 4 kolom,
/// rail extended, dan two-pane. Phone/tablet di bawahnya tidak berubah.
const double kWideBreakpoint = 1400;

/// Lebar dialog/sheet terpusat di tablet/desktop.
const double kDialogMaxWidth = 560;

bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kTabletBreakpoint;
bool isExpanded(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kExpandedBreakpoint;
bool isDesktopWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;

/// True untuk tablet hardware (sisi terpendek ≥ 600dp), tidak tergantung
/// orientasi — tablet portrait (mis. 800×1280, lebar 800 < 840) tetap
/// terdeteksi tablet, phone tidak (sisi terpendek < 600).
bool isTabletDevice(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= kTabletBreakpoint;

/// Keputusan navigasi rel kiri: selalu untuk tablet (semua orientasi);
/// phone hanya saat landscape lebar (≥840). Pengganti isExpanded khusus
/// untuk keputusan nav chrome (rail vs bottom bar).
bool useNavRail(BuildContext context) =>
    isTabletDevice(context) || isExpanded(context);

/// Kolom grid kartu form (FormCard): 1 phone, 2 tablet portrait,
/// 3 tablet landscape/layar lebar, 4 ekstra-lebar. Satu sumber agar
/// Beranda, Form Saya, dan tab Drive selalu konsisten — jangan duplikasi
/// ambang ini di tiap screen.
int formGridColumns(double width) => width >= kWideBreakpoint
    ? 4
    : width >= kExpandedBreakpoint
        ? 3
        : width >= kTabletBreakpoint
            ? 2
            : 1;

/// True di Windows/macOS/Linux desktop (bukan web/mobile) — dipakai untuk
/// guard fitur yang tidak didukung di desktop (kamera image_picker, QR
/// mobile_scanner). Aman untuk web (tanpa dart:io).
bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Padding horizontal adaptif: phone (<600) mengembalikan [base] apa adanya
/// (render identik), tablet/desktop melebarkan sisi kiri-kanan sehingga konten
/// terpusat selebar [maxWidth] — atau [wideMaxWidth] di layar ekstra-lebar
/// (≥1400, mis. 1920×1080). Untuk layar scroll (ListView/
/// SingleChildScrollView/CustomScrollView) — tanpa ubah struktur widget.
EdgeInsets centerPad(
  BuildContext context, {
  required EdgeInsets base,
  double maxWidth = 720,
  double? wideMaxWidth,
}) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < kTabletBreakpoint) return base;
  final cap = (wideMaxWidth != null && w >= kWideBreakpoint)
      ? wideMaxWidth
      : maxWidth;
  final side = (w - cap) / 2;
  if (side <= 0) return base;
  return base.copyWith(
    left: base.left > side ? base.left : side,
    right: base.right > side ? base.right : side,
  );
}

/// Center content dengan maxWidth di tablet, phone return child apa adanya.
/// [wideMaxWidth] dipakai di layar ekstra-lebar (≥1400).
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double? wideMaxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.wideMaxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < kTabletBreakpoint) return child;
    final cap = (wideMaxWidth != null && w >= kWideBreakpoint)
        ? wideMaxWidth!
        : maxWidth;
    final pw = w >= kExpandedBreakpoint ? 32.0 : 24.0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: pw),
          child: child,
        ),
      ),
    );
  }
}

/// Grid responsif: 1 kolom phone, 2 tablet, 3 expanded, 4 ekstra-lebar (≥1400).
/// [columnCountFor] meng-override pemetaan kolom per lebar (mis. Form Saya:
/// 2/4/6). Tanpa override, perilaku lama dipertahankan (phone identik).
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double crossSpacing;
  final double mainSpacing;
  final double maxWidth;
  final bool compact;
  final int Function(double width)? columnCountFor;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.crossSpacing = 16,
    this.mainSpacing = 16,
    this.maxWidth = 1100,
    this.compact = false,
    this.columnCountFor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Jika di dalam ResponsiveCenter, constraints sudah capped; fallback ke MediaQuery
        final effectiveW = w < 100 ? MediaQuery.sizeOf(context).width : w;
        final override = columnCountFor;
        final cols = override != null
            ? override(effectiveW)
            : effectiveW >= kWideBreakpoint
            ? 4
            : effectiveW >= kExpandedBreakpoint
            ? 3
            : effectiveW >= kTabletBreakpoint
            ? 2
            : 1;
        if (cols == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) SizedBox(height: mainSpacing),
              ],
            ],
          );
        }
        // Gunakan Wrap agar tinggi card otomatis (beranda compact = pendek, form dengan banner = tinggi adaptif)
        final itemWidth = (effectiveW - crossSpacing * (cols - 1)) / cols;
        return Wrap(
          spacing: crossSpacing,
          runSpacing: mainSpacing,
          children: [
            for (final c in children) SizedBox(width: itemWidth, child: c),
          ],
        );
      },
    );
  }
}

/// Dialog terpusat berlebar tetap — ganti AlertDialog polos agar tidak
/// raksasa di monitor lebar. Di phone (<600) tampil normal tanpa constraint.
class ResponsiveDialog extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveDialog({
    super.key,
    required this.child,
    this.maxWidth = kDialogMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (!isTablet(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Satu pintu sheet adaptif: phone (<600) = bottom sheet persis seperti
/// sekarang (semua param gaya diteruskan agar render identik),
/// tablet/desktop = dialog terpusat berlebar tetap. [builder] menerima
/// ScrollController agar DraggableScrollableSheet tetap bisa dipakai.
class AdaptiveSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(
      BuildContext context,
      ScrollController scrollController,
    )
    builder,
    double maxWidth = kDialogMaxWidth,
    bool isDismissible = true,
    bool isScrollControlled = false,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
  }) {
    if (!isTablet(context)) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        backgroundColor: backgroundColor,
        elevation: elevation,
        shape: shape,
        isDismissible: isDismissible,
        builder: (ctx) => builder(ctx, ScrollController()),
      );
    }
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Dialog(
          backgroundColor: backgroundColor ?? cs.surface,
          elevation: elevation,
          shape: shape ??
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              child: builder(ctx, ScrollController()),
            ),
          ),
        );
      },
    );
  }

  /// Varian sederhana tanpa ScrollController untuk konten pendek.
  static Future<T?> showSimple<T>({
    required BuildContext context,
    required Widget child,
    double maxWidth = kDialogMaxWidth,
    bool isDismissible = true,
  }) {
    return show(
      context: context,
      isDismissible: isDismissible,
      maxWidth: maxWidth,
      builder: (ctx, _) => child,
    );
  }
}
