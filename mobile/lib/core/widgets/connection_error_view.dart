import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Tampilan error koneksi standar: ikon wifi-off + pesan + tombol "Coba Lagi".
/// Dipakai SEMUA layar yang fetch API bila [AuthService.isConnectionError]
/// bernilai true — jangan tampilkan tampilan "data kosong" dalam kasus ini.
///
/// Dibungkus [Center] + padding agar aman dipakai di dalam ListView,
/// Column, maupun SliverFillRemaining.
class ConnectionErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool bare;

  const ConnectionErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.bare = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: cs.errorContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(Icons.wifi_off_outlined, color: cs.error, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          'Gagal terhubung',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message.isEmpty
              ? 'Periksa koneksi internet kamu dan coba lagi.'
              : message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Coba Lagi'),
        ),
      ],
    );
    if (bare) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: content,
        ),
      );
    }
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: content,
      ),
    );
  }
}
