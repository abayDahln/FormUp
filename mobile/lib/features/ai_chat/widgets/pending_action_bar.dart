import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Bar persetujuan aksi form dari AI: tampil DI ATAS field prompt
/// (bukan dialog) dengan tombol Terima / Tolak. Muncul hanya bila ada
/// aksi berstatus pending di session aktif.
class PendingActionBar extends StatelessWidget {
  final Map<String, dynamic> action;
  final bool isWorking;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const PendingActionBar({
    super.key,
    required this.action,
    required this.isWorking,
    required this.onAccept,
    required this.onReject,
  });

  String _describe() {
    switch (action['action']) {
      case 'create_form':
        final title = action['title'] as String?;
        return title == null || title.isEmpty
            ? 'Membuat form baru'
            : 'Membuat form "$title"';
      case 'add_questions':
        final count = (action['questions'] as List<dynamic>?)?.length ?? 0;
        final formId = action['formId'];
        return formId == null
            ? 'Menambah $count soal'
            : 'Menambah $count soal ke form #$formId';
      case 'edit_questions':
        final count = (action['questions'] as List<dynamic>?)?.length ?? 0;
        final formId = action['formId'];
        return formId == null
            ? 'Mengubah $count soal'
            : 'Mengubah $count soal di form #$formId';
      case 'delete_questions':
        final count = (action['questionIds'] as List<dynamic>?)?.length ?? 0;
        final formId = action['formId'];
        return formId == null
            ? 'Menghapus $count soal'
            : 'Menghapus $count soal dari form #$formId';
      case 'update_settings':
        final formId = action['formId'];
        return formId == null
            ? 'Mengubah pengaturan form'
            : 'Mengubah pengaturan form #$formId';
      default:
        return 'Menjalankan aksi ${action['action']}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBDC9C8)),
          boxShadow: softShadow(),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: kPrimarySoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 15,
                color: kAuthPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI ingin menjalankan perubahan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _describe(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Tolak di kiri, Terima di kanan (utama).
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: Colors.black54,
              ),
              onPressed: isWorking ? null : onReject,
              child: const Text('Tolak', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 2),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kAuthPrimary,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: isWorking ? null : onAccept,
              child: isWorking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Terima', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
