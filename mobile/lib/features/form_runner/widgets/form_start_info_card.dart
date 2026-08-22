import 'package:flutter/material.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Kartu informasi form: judul, deskripsi, detail soal/timer/waktu, dan token
class FormStartInfoCard extends StatelessWidget {
  final PublicFormInfo info;
  final TextEditingController tokenController;
  final String? tokenError;

  const FormStartInfoCard({
    super.key,
    required this.info,
    required this.tokenController,
    required this.tokenError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichTextView(
            text: info.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          if (info.description != null && info.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            RichTextView(
              text: info.description!,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],

          const Divider(height: 32),

          // Total questions
          _DetailRow(
            icon: Icons.quiz_outlined,
            label: "Total Pertanyaan",
            value: "${info.questionCount} soal",
          ),

          // Timer (jika ada)
          if (info.timerDuration != null && info.timerDuration! > 0) ...[
            const Divider(height: 24),
            _DetailRow(
              icon: Icons.timer_outlined,
              label: "Batas Waktu Pengerjaan",
              value: _formatDuration(info.timerDuration!),
            ),
          ],

          // Jam buka form
          if (info.openFormTime != null) ...[
            const Divider(height: 24),
            _DetailRow(
              icon: Icons.play_circle_outline,
              label: "Form Dibuka",
              value: _formatDateTime(info.openFormTime!),
            ),
          ],

          // Jam tutup form
          if (info.closeFormTime != null) ...[
            const Divider(height: 24),
            _DetailRow(
              icon: Icons.stop_circle_outlined,
              label: "Form Ditutup",
              value: _formatDateTime(info.closeFormTime!),
            ),
          ],

          // Input token - digabung ke dalam kartu informasi
          if (info.requiresToken) ...[
            const Divider(height: 32),
            const Row(
              children: [
                Icon(Icons.lock_outline, size: 18, color: kAuthPrimary),
                SizedBox(width: 8),
                Text(
                  "Form Ini Memerlukan Token",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: kAuthPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: tokenController,
              hint: "Masukkan token akses",
              icon: Icons.key,
            ),
            if (tokenError != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Color(0xFFC0392B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tokenError!,
                      style:
                          const TextStyle(fontSize: 12, color: Color(0xFFC0392B)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                "Token diberikan oleh pemilik form. Hubungi pemilik untuk mendapatkan token.",
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Satu baris detail ikon + label + nilai
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kPrimarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kAuthPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Format durasi dari detik menjadi "X jam Y menit" / "Y menit"
String _formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0 && m > 0) return "$h jam $m menit";
  if (h > 0) return "$h jam";
  if (m > 0) return "$m menit";
  return "$seconds detik";
}

String _formatDateTime(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return "${local.day} ${months[local.month - 1]} ${local.year}, $hh:$mm";
}
