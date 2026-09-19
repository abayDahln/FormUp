import 'package:flutter/material.dart';

/// Tombol filter pil ala M3 Extended (icon + label) untuk layout tablet &
/// desktop — dipakai di samping search field (Form Saya, Respons).
///
/// Mengikuti contoh: teks reguler (tidak tebal), radius pil penuh
/// (StadiumBorder). Tinggi 48 disamakan dengan search bar di sebelahnya
/// (TextField setinggi 48 dari constraint ikon 48px + padding vertikal).
/// Warna, padding horizontal, dan font TIDAK diubah — mewarisi tema
/// aplikasi (filledButtonTheme) seperti tombol filter saat ini.
class FilterPillButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool active;

  const FilterPillButton({
    super.key,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.normal),
      ),
      icon: const Icon(Icons.tune, size: 18),
      label: Text(active ? 'Filter aktif' : 'Filter'),
    );
  }
}
