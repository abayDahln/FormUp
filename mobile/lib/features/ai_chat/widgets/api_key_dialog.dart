import 'package:flutter/material.dart';
import 'package:form_up/core/services/gemini_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Dialog pengaturan Gemini API Key.
Future<void> showAiApiKeyDialog(
  BuildContext context, {
  required VoidCallback onKeyChanged,
}) async {
  final ctrl = TextEditingController(text: GeminiService.userKey ?? '');
  final isUserKey = GeminiService.isUserKey;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Atur Gemini API Key',
            style: TextStyle(fontFamily: kFontBold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Dapatkan gratis di https://aistudio.google.com/app/apikey',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                if (GeminiService.hasKey)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.key,
                          size: 14,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            GeminiService.maskedKey,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isUserKey
                                ? Colors.green.shade100
                                : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isUserKey ? 'Tersimpan di App' : 'Dari .env',
                            style: TextStyle(
                              fontSize: 10,
                              color: isUserKey
                                  ? Colors.green.shade800
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'GEMINI_API_KEY',
                    hintText: 'AIza...',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Key akan dienkripsi dan tersimpan di perangkat. Tidak perlu restart.',
                  style: TextStyle(fontSize: 10, color: Colors.black45),
                ),
              ],
            ),
          ),
          actions: [
            if (isUserKey)
              TextButton(
                onPressed: () async {
                  await GeminiService.clearUserKey();
                  onKeyChanged();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    showAuthToast(
                      context,
                      'API Key dihapus (fallback ke .env jika ada)',
                    );
                  }
                },
                child: const Text(
                  'Hapus',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final v = ctrl.text.trim();
                if (v.isEmpty) {
                  showAuthToast(
                    context,
                    'Key tidak boleh kosong',
                    isError: true,
                  );
                  return;
                }
                await GeminiService.setUserKey(v);
                onKeyChanged();
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  showAuthToast(context, 'API Key tersimpan aman di aplikasi');
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    ),
  );
}
