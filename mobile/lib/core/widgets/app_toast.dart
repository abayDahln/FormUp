import 'dart:async';

import 'package:flutter/material.dart';

/// Varian toast gaya flat colored (bg tint + border warna varian)
enum ToastType { success, info, warning, error }

class _ToastVariant {
  final Color color;
  final IconData icon;
  final String defaultTitle;

  const _ToastVariant(this.color, this.icon, this.defaultTitle);
}

ToastType? _mapLegacy(bool isError) =>
    isError ? ToastType.error : ToastType.success;

const Map<ToastType, _ToastVariant> _variants = {
  ToastType.success:
      _ToastVariant(Color(0xFF2E7D32), Icons.check_circle_outline, 'Berhasil'),
  ToastType.info: _ToastVariant(Color(0xFF1E88E5), Icons.info_outline, 'Info'),
  ToastType.warning:
      _ToastVariant(Color(0xFFB26A00), Icons.warning_amber_outlined, 'Peringatan'),
  ToastType.error: _ToastVariant(
      Color(0xFFC0392B), Icons.cancel_outlined, 'Gagal'),
};

OverlayEntry? _activeEntry;
Timer? _activeTimer;

/// Toast top-floating dengan animasi slide dari atas.
/// Durasi tampil default 2.5s (error 3.2s) lalu slide ke atas otomatis hilang.
void showAppToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.success,
  String? title,
  Duration? duration,
}) {
  final effectiveDuration = duration ??
      (type == ToastType.error
          ? const Duration(milliseconds: 3200)
          : type == ToastType.warning
              ? const Duration(milliseconds: 2800)
              : const Duration(milliseconds: 2500));
  final overlay = Overlay.of(context);
  final v = _variants[type]!;

  _dismissActive();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _TopToastEntry(
      variant: v,
      message: message,
      title: title,
      duration: effectiveDuration,
      onDismiss: () => _dismiss(entry),
    ),
  );

  _activeEntry = entry;
  overlay.insert(entry);
  // Timer pengaman jika widget tidak auto-dismiss (mis. dispose cepat)
  _activeTimer = Timer(effectiveDuration + const Duration(milliseconds: 400), () {
    if (entry.mounted) _dismiss(entry);
  });
}

void _dismissActive() {
  _activeTimer?.cancel();
  _activeTimer = null;
  if (_activeEntry?.mounted == true) _activeEntry!.remove();
  _activeEntry = null;
}

void _dismiss(OverlayEntry entry) {
  _activeTimer?.cancel();
  _activeTimer = null;
  if (entry.mounted) entry.remove();
  if (_activeEntry == entry) _activeEntry = null;
}

/// Wrapper kompatibel untuk pemanggil lama showAuthToast.
void showAuthToast(
  BuildContext context,
  String message, {
  bool isError = false,
  ToastType? type,
  String? title,
  Duration? duration,
}) {
  showAppToast(
    context,
    message,
    type: type ?? _mapLegacy(isError)!,
    title: title,
    duration: duration,
  );
}

class _TopToastEntry extends StatefulWidget {
  final _ToastVariant variant;
  final String message;
  final String? title;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopToastEntry({
    required this.variant,
    required this.message,
    this.title,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopToastEntry> createState() => _TopToastEntryState();
}

class _TopToastEntryState extends State<_TopToastEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  late final Animation<double> _opacity;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _offset = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
    );
    _controller.forward();
    _hideTimer = Timer(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.variant;
    final topPadding = MediaQuery.of(context).viewPadding.top + 12;
    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offset,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                color: Color.alphaBlend(v.color.withValues(alpha: 0.14), Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: v.color.withValues(alpha: 0.55)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(v.icon, color: v.color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title ?? v.defaultTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.3,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        if (widget.message.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 12,
                              color: v.color,
                              height: 1.35,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () async {
                      _hideTimer?.cancel();
                      await _controller.reverse();
                      widget.onDismiss();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: v.color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
