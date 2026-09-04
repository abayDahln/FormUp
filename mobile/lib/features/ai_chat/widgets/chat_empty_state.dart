import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Tampilan saat chat masih kosong: ilustrasi + contoh + chip cepat.
class ChatEmptyState extends StatelessWidget {
  /// Padding atas (area di bawah header overlay).
  final double topPadding;

  /// Dipanggil dengan teks siap kirim saat chip diketuk.
  final ValueChanged<String> onQuickSend;

  const ChatEmptyState({
    super.key,
    required this.topPadding,
    required this.onQuickSend,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(32, topPadding, 32, 180),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: softShadow(),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: kAuthPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tanya AI untuk membuat form',
              style: TextStyle(fontFamily: kFontBold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Contoh: "Buatkan form kuis matematika 10 soal pilihan ganda tentang aljabar" atau "Edit form #12 tambahkan 5 soal essay"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickChip(
                  'Buat kuis 5 soal',
                  () => onQuickSend(
                    'Buatkan form kuis 5 soal pilihan ganda tentang sejarah Indonesia',
                  ),
                ),
                _QuickChip(
                  'Form survey',
                  () => onQuickSend(
                    'Buatkan form survey kepuasan pelanggan 7 pertanyaan',
                  ),
                ),
                _QuickChip(
                  'Edit form',
                  () => onQuickSend(
                    'Tambahkan 3 soal essay ke form terakhir saya',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFBDC9C8)),
      ),
    );
  }
}
