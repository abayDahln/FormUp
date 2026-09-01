import 'package:flutter/material.dart';

const double kTabletBreakpoint = 600;
const double kExpandedBreakpoint = 840;

bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).width >= kTabletBreakpoint;
bool isExpanded(BuildContext context) => MediaQuery.sizeOf(context).width >= kExpandedBreakpoint;

/// Center content dengan maxWidth di tablet, phone return child apa adanya.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < kTabletBreakpoint) return child;
    final pw = w >= kExpandedBreakpoint ? 32.0 : 24.0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: pw),
          child: child,
        ),
      ),
    );
  }
}

/// Grid responsif: 1 kolom phone, 2 kolom tablet, 3 kolom expanded
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double crossSpacing;
  final double mainSpacing;
  final double maxWidth;
  final bool compact;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.crossSpacing = 16,
    this.mainSpacing = 16,
    this.maxWidth = 1100,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      // Jika di dalam ResponsiveCenter, constraints sudah capped; fallback ke MediaQuery
      final effectiveW = w < 100 ? MediaQuery.sizeOf(context).width : w;
      final cols = effectiveW >= kExpandedBreakpoint ? 3 : effectiveW >= kTabletBreakpoint ? 2 : 1;
      if (cols == 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (var i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) SizedBox(height: mainSpacing)]],
        );
      }
      // Gunakan Wrap agar tinggi card otomatis (beranda compact = pendek, form dengan banner = tinggi adaptif)
      final itemWidth = (effectiveW - crossSpacing * (cols - 1)) / cols;
      return Wrap(
        spacing: crossSpacing,
        runSpacing: mainSpacing,
        children: [for (final c in children) SizedBox(width: itemWidth, child: c)],
      );
    });
  }
}
