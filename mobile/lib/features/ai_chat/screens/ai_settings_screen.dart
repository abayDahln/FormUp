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
              const Text('Dapatkan gratis di https://aistudio.google.com/app/apikey', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 8),
              if (GeminiService.hasKey)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF0F4F4), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.key, size: 14, color: Colors.black54),
                    const SizedBox(width: 6),
                    Expanded(child: Text(GeminiService.maskedKey, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: isUserKey ? Colors.green.shade100 : Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                      child: Text(isUserKey ? 'Tersimpan di App' : 'Dari .env', style: TextStyle(fontSize: 10, color: isUserKey ? Colors.green.shade800 : Colors.black87)),
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
              const Text('Key akan dienkripsi dan tersimpan di perangkat. Tidak perlu restart.', style: TextStyle(fontSize: 10, color: Colors.black45)),
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
    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: kAppBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Pengaturan AI', style: TextStyle(fontFamily: kFontBold, fontSize: 18, color: Colors.black87)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // API Key card
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
            child: Column(children: [
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kPrimarySoft, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.key_outlined, color: kAuthPrimary, size: 20)),
                title: const Text('API Key Gemini', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(GeminiService.hasKey ? GeminiService.maskedKey : 'Belum diatur', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.black45),
                onTap: _showApiKeyDialog,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kPrimarySoft, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.info_outline, color: kAuthPrimary, size: 20)),
                title: const Text('Dapatkan API Key', style: TextStyle(fontSize: 14)),
                subtitle: const Text('aistudio.google.com/app/apikey', style: TextStyle(fontSize: 11, color: Colors.black54)),
                trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.black45),
                onTap: () => showAuthToast(context, 'Buka https://aistudio.google.com/app/apikey di browser'),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Riwayat Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.black54)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
            child: Column(children: [
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_sweep_outlined, color: Colors.red, size: 20)),
                title: const Text('Hapus semua riwayat', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Semua chat akan hilang permanen', style: TextStyle(fontSize: 11, color: Colors.black54)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.black45),
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
