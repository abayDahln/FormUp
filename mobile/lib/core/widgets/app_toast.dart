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

/// Toast gaya flat colored untuk seluruh aplikasi.
///
/// [message] tampil sebagai deskripsi di bawah judul; [title] opsional
/// (default mengikuti varian: Berhasil / Info / Peringatan / Gagal).
void showAppToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.success,
  String? title,
  Duration duration = const Duration(milliseconds: 3000),
}) {
  final overlay = Overlay.of(context);
  final v = _variants[type]!;

  // Ganti toast yang masih tampil agar tidak menumpuk
  _dismissActive();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 20,
      right: 20,
      top: MediaQuery.of(context).viewPadding.top + 12,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: v.color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: v.color.withValues(alpha: 0.55)),
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
                      title ?? v.defaultTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        message,
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
                onTap: () => _dismiss(entry),
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
  );

  _activeEntry = entry;
  overlay.insert(entry);
  _activeTimer = Timer(duration, () => _dismiss(entry));
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
/// [isError] dipetakan ke varian error/success.
void showAuthToast(
  BuildContext context,
  String message, {
  bool isError = false,
  ToastType? type,
  String? title,
}) {
  showAppToast(
    context,
    message,
    type: type ?? _mapLegacy(isError)!,
    title: title,
  );
}
