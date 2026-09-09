import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Bottom sheet panduan pengguna (paritas web UserGuideModal):
/// 5 tab + tombol "Mulai Tur Interaktif" di footer.
class UserGuideSheet extends StatefulWidget {
  /// Dipanggil saat user menekan "Mulai Tur Interaktif".
  final VoidCallback? onStartTour;

  const UserGuideSheet({super.key, this.onStartTour});

  static Future<void> show(BuildContext context, {VoidCallback? onStartTour}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) =>
            UserGuideSheet(onStartTour: onStartTour),
      ),
    );
  }

  @override
  State<UserGuideSheet> createState() => _UserGuideSheetState();
}

class _UserGuideSheetState extends State<UserGuideSheet> {
  int _tab = 0;

  static const _tabs = [
    (Icons.bolt_outlined, 'Mulai'),
    (Icons.edit_note_outlined, 'Buat Form'),
    (Icons.auto_awesome_outlined, 'AI & Ujian'),
    (Icons.bar_chart_outlined, 'Respons'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.book_outlined,
                      color: cs.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panduan Pengguna FormUp',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                        ),
                      ),
                      Text(
                        'Pelajari cara memakai aplikasi',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final active = i == _tab;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_tabs[i].$1, size: 15),
                      const SizedBox(width: 4),
                      Text(_tabs[i].$2),
                    ],
                  ),
                  selected: active,
                  onSelected: (_) => setState(() => _tab = i),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _tabBody(cs),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: AuthPrimaryButton(
                    label: 'Mulai Tur Interaktif',
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onStartTour?.call();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kRadius),
                      ),
                    ),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBody(ColorScheme cs) {
    switch (_tab) {
      case 0:
        return Column(
          children: [
            _tipCard(cs, Icons.rocket_launch_outlined, 'Mulai cepat',
                'Urutannya: Beranda → buat Form → minta AI buatkan soal → pantau Respons.'),
            _bullet(cs, 'Kerjakan form orang lain via kode / QR di Beranda.'),
            _bullet(cs, 'Semua menu ada di bar bawah: Form, AI Chat, Respons, Profil.'),
          ],
        );
      case 1:
        return Column(
          children: [
            _tipCard(cs, Icons.edit_note_outlined, 'Buat form',
                'Tab Form → + → isi judul → Kelola Soal → Simpan → bagikan link/QR.'),
            _bullet(cs, 'Tipe soal: pilihan ganda, checkbox, essay, benar/salah.'),
            _bullet(cs, 'Jangan lupa kunci jawaban + poin untuk nilai otomatis.'),
          ],
        );
      case 2:
        return Column(
          children: [
            _tipCard(cs, Icons.auto_awesome_outlined, 'AI & ujian',
                'Contoh: "Buatkan 5 soal tentang fotosintesis". Periksa → Terima.'),
            _bullet(cs, 'Sebut @nama form agar AI fokus ke form itu.'),
            _bullet(cs, 'Aktifkan mode ujian untuk kunci layar + tandai soal ragu-ragu (kuning).'),
          ],
        );
      default:
        return Column(
          children: [
            _tipCard(cs, Icons.bar_chart_outlined, 'Respons & nilai',
                'Lihat isian responden, nilai otomatis, dan koreksi essay manual.'),
            _bullet(cs, 'Ekspor hasil ke CSV / Excel / PDF.'),
            _bullet(cs, 'Butuh bantuan lagi? Ulangi tur dari sini.'),
          ],
        );
    }
  }

  Widget _tipCard(ColorScheme cs, IconData icon, String title, String desc) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                    )),
                const SizedBox(height: 4),
                Text(desc,
                    style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(ColorScheme cs, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 17, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, height: 1.45)),
          ),
        ],
      ),
    );
  }
}
