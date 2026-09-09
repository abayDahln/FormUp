import 'package:flutter/material.dart';
import 'package:form_up/core/services/ai_chat_history_service.dart';
import 'package:form_up/core/services/gemini_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});
  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  Future<void> _showApiKeyDialog() async {
    final ctrl = TextEditingController(text: GeminiService.userKey ?? '');
    final isUserKey = GeminiService.isUserKey;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Atur Gemini API Key', style: TextStyle(fontFamily: kFontBold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
               Text('Dapatkan gratis di https://aistudio.google.com/app/apikey', style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              if (GeminiService.hasKey)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                     Icon(Icons.key, size: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(child: Text(GeminiService.maskedKey, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: isUserKey ? Colors.green.shade100 : Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                      child: Text(isUserKey ? 'Tersimpan di App' : 'Dari .env', style: TextStyle(fontSize: 11, color: isUserKey ? Colors.green.shade800 : Theme.of(ctx).colorScheme.onSurface)),
                    ),
                  ]),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'GEMINI_API_KEY', hintText: 'AIza...', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 8),
               Text('Key akan dienkripsi dan tersimpan di perangkat. Tidak perlu restart.', style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ]),
          ),
          actions: [
            if (isUserKey)
              TextButton(
                onPressed: () async {
                  await GeminiService.clearUserKey();
                  if (mounted) setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) showAuthToast(context, 'API Key dihapus (fallback ke .env jika ada)');
                },
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                final v = ctrl.text.trim();
                if (v.isEmpty) {
                  showAuthToast(context, 'Key tidak boleh kosong', isError: true);
                  return;
                }
                await GeminiService.setUserKey(v);
                if (mounted) setState(() {});
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) showAuthToast(context, 'API Key tersimpan aman di aplikasi');
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon:  Icon(Icons.arrow_back, color: cs.onSurface), onPressed: () => Navigator.pop(context)),
        title:  Text('Pengaturan AI', style: TextStyle(fontFamily: kFontBold, fontSize: 18, color: cs.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // API Key card
          Container(
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
            child: Column(children: [
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)), child:  Icon(Icons.key_outlined, color: cs.primary, size: 20)),
                title: const Text('API Key Gemini', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: kFontBold)),
                subtitle: Text(GeminiService.hasKey ? GeminiService.maskedKey : 'Belum diatur', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                trailing:  Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
                onTap: _showApiKeyDialog,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)), child:  Icon(Icons.info_outline, color: cs.primary, size: 20)),
                title: const Text('Dapatkan API Key', style: TextStyle(fontSize: 14)),
                subtitle:  Text('aistudio.google.com/app/apikey', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                trailing:  Icon(Icons.open_in_new, size: 16, color: cs.onSurfaceVariant),
                onTap: () => showAuthToast(context, 'Buka https://aistudio.google.com/app/apikey di browser'),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Text('Riwayat Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: kFontBold, letterSpacing: 0.8, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
            child: Column(children: [
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_sweep_outlined, color: Colors.red, size: 20)),
                title: const Text('Hapus semua riwayat', style: TextStyle(fontSize: 14)),
                subtitle:  Text('Semua chat akan hilang permanen', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                trailing:  Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
                onTap: () async {
                  final c = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Hapus semua?'), content: const Text('Semua riwayat chat akan hilang.'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Hapus'))]));
                  if (c == true) {
                    await AiChatHistoryService.clearAll();
                    if (mounted) {
                      showAuthToast(context, 'Semua riwayat dihapus');
                      setState(() {});
                    }
                  }
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
