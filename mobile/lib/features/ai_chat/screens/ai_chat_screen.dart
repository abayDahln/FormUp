import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:form_up/core/services/ai_chat_history_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/gemini_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/ai_chat_icon.dart';
import 'package:form_up/core/router/app_router.dart';

class ChatMessage {
  final String role; // user | model
  String text;
  final DateTime time;
  Map<String, dynamic>? actionJson;
  bool actionExecuted = false;
  String? actionResult;
  ChatMessage({required this.role, required this.text, DateTime? time, this.actionJson})
      : time = time ?? DateTime.now();
}

class AiChatScreen extends StatefulWidget {
  final bool embedded;
  const AiChatScreen({super.key, this.embedded = false});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];
  String? _currentSessionId;
  bool _streaming = false;
  StreamSubscription<String>? _sub;
  static bool _shownInitialMissingKeyToast = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    // Toast sekali saat baru membuka app & membuka screen AI chat jika key belum diatur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_shownInitialMissingKeyToast && !GeminiService.hasKey && mounted) {
        _shownInitialMissingKeyToast = true;
        showAuthToast(context, 'Api Key belum diatur. Tambahkan sekarang di pengaturan', isError: true);
      }
    });
  }

  Future<void> _loadSessions() async {
    final all = await AiChatHistoryService.loadAll();
    if (!mounted) return;
    setState(() => _sessions = all);
    if (_sessions.isEmpty) {
      // Jangan auto-buat session kosong (anti spam) — buat id in-memory saja
      if (_currentSessionId == null) {
        setState(() {
          _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
          _messages.clear();
        });
      }
    } else if (_currentSessionId == null) {
      // load most recent
      await _switchSession(_sessions.first.id);
    }
  }

  Future<void> _persistCurrent() async {
    if (_currentSessionId == null) return;
    if (_messages.isEmpty) return;
    final title = _messages.firstWhere((m) => m.role == 'user', orElse: () => _messages.first).text.trim();
    final short = title.length > 40 ? '${title.substring(0, 40)}…' : title;
    final session = ChatSession(
      id: _currentSessionId!,
      title: short.isEmpty ? 'Chat baru' : short,
      messages: _messages.map((m) => ChatHistoryMessage(role: m.role, text: m.text)).toList(),
      updatedAt: DateTime.now(),
    );
    await AiChatHistoryService.upsert(session);
    final all = await AiChatHistoryService.loadAll();
    if (mounted) setState(() => _sessions = all);
  }

  Future<void> _newSession() async {
    // Anti spam: chat baru hanya jika sudah ada prompt yang dikirim
    if (_messages.isEmpty) {
      // Jika sudah ada session kosong yang belum tersimpan, jangan buat lagi
      if (_sessions.isEmpty || _currentSessionId != null) {
        if (mounted && _sessions.isNotEmpty) {
          showAuthToast(context, 'Chat masih kosong');
        }
        // Jika belum ada session sama sekali, cukup reset id in-memory
        if (_sessions.isEmpty) {
          setState(() {
            _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
            _messages.clear();
          });
        }
        return;
      }
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    if (!mounted) return;
    setState(() {
      _currentSessionId = id;
      _messages.clear();
    });
    // Jangan langsung upsert kosong — akan tersimpan otomatis saat prompt pertama dikirim (_persistCurrent)
  }

  Future<void> _switchSession(String id) async {
    final all = await AiChatHistoryService.loadAll();
    final target = all.firstWhere((e) => e.id == id, orElse: () => all.first);
    if (!mounted) return;
    setState(() {
      _currentSessionId = id;
      _messages
        ..clear()
        ..addAll(target.messages.map((m) => ChatMessage(role: m.role, text: m.text)));
    });
  }

  Future<void> _deleteSession(String id) async {
    await AiChatHistoryService.delete(id);
    if (_currentSessionId == id) {
      setState(() {
        _messages.clear();
        _currentSessionId = null;
      });
      final all = await AiChatHistoryService.loadAll();
      if (!mounted) return;
      if (all.isEmpty) {
        await _newSession();
      } else {
        await _switchSession(all.first.id);
      }
    }
    await _loadSessions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _sub?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Map<String, dynamic>? _extractJson(String text) {
    final fence = RegExp(r'```json\s*([\s\S]*?)\s*```', caseSensitive: false);
    final m = fence.firstMatch(text);
    String? candidate;
    if (m != null) candidate = m.group(1);
    if (candidate == null) {
      final brace = RegExp(r'\{[\s\S]*"action"[\s\S]*\}');
      final m2 = brace.firstMatch(text);
      if (m2 != null) candidate = m2.group(0);
    }
    if (candidate == null) return null;
    try {
      final j = jsonDecode(candidate) as Map<String, dynamic>;
      if (j.containsKey('action')) return j;
    } catch (_) {}
    return null;
  }

  Future<void> _executeAction(Map<String, dynamic> action) async {
    final act = action['action'] as String?;
    try {
      switch (act) {
        case 'create_form':
          final title = action['title'] as String? ?? 'Form AI';
          final description = action['description'] as String?;
          final formId = await FormService.createForm(title: title, description: description);
          final questions = (action['questions'] as List<dynamic>?) ?? [];
          if (questions.isNotEmpty) {
            final payload = questions.map((q) {
              final map = Map<String, dynamic>.from(q as Map);
              if (map['options'] is List) {
                map['options'] = (map['options'] as List).map((o) {
                  if (o is String) return {'optionText': o};
                  return Map<String, dynamic>.from(o as Map);
                }).toList();
              }
              return map;
            }).toList();
            await FormService.saveQuestions(formId, payload);
          }
          return;
        case 'add_questions':
          final formId = action['formId'] as int?;
          if (formId == null) throw Exception('formId diperlukan');
          final questions = (action['questions'] as List<dynamic>?) ?? [];
          final payload = questions.map((q) => Map<String, dynamic>.from(q as Map)).toList();
          await FormService.saveQuestions(formId, payload);
          return;
        case 'update_settings':
          final formId = action['formId'] as int?;
          if (formId == null) throw Exception('formId diperlukan');
          final settings = Map<String, dynamic>.from(action['settings'] as Map? ?? {});
          await FormService.updateSettings(formId, settings);
          return;
        default:
          throw Exception('Aksi tidak dikenal: $act');
      }
    } catch (e) {
      throw Exception(AuthService.errorMessage(e));
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _streaming) return;
    if (!GeminiService.hasKey) {
      showAuthToast(context, 'GEMINI_API_KEY belum diatur', isError: true);
      _showApiKeyDialog();
      return;
    }
    // ensure session exists
    if (_currentSessionId == null) await _newSession();
    final userMsg = ChatMessage(role: 'user', text: text);
    setState(() {
      _messages.add(userMsg);
      _controller.clear();
    });
    _scrollToBottom();
    await _persistCurrent();

    final history = _messages.map((m) => {'role': m.role, 'text': m.text}).toList();
    final botMsg = ChatMessage(role: 'model', text: '');
    setState(() {
      _messages.add(botMsg);
      _streaming = true;
    });

    final buffer = StringBuffer();
    try {
      _sub = GeminiService.streamChat(history).listen(
        (chunk) {
          buffer.write(chunk);
          setState(() => botMsg.text = buffer.toString());
          _scrollToBottom();
        },
        onDone: () async {
          setState(() => _streaming = false);
          await _persistCurrent();
          final action = _extractJson(botMsg.text);
          if (action != null) {
            botMsg.actionJson = action;
            setState(() {});
            if (mounted) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Jalankan Aksi AI?', style: TextStyle(fontFamily: kFontBold, fontSize: 14)),
                  content: SingleChildScrollView(child: Text(jsonEncode(action), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Jalankan')),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  await _executeAction(action);
                  botMsg.actionExecuted = true;
                  botMsg.actionResult = 'Berhasil dijalankan';
                  if (mounted) {
                    showAuthToast(context, 'Aksi ${action['action']} berhasil');
                    setState(() {});
                  }
                } catch (e) {
                  botMsg.actionResult = 'Gagal: $e';
                  if (mounted) showAuthToast(context, 'Gagal menjalankan aksi: $e', isError: true);
                  setState(() {});
                }
                await _persistCurrent();
              }
            }
          }
          await _persistCurrent();
        },
        onError: (e) async {
          try {
            final full = await GeminiService.generateOnce(history);
            setState(() {
              botMsg.text = full;
              _streaming = false;
            });
            await _persistCurrent();
          } catch (e2) {
            setState(() {
              botMsg.text = 'Error: ${AuthService.errorMessage(e)}';
              _streaming = false;
            });
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      setState(() {
        botMsg.text = 'Error: ${AuthService.errorMessage(e)}';
        _streaming = false;
      });
    }
  }

  Future<void> _showApiKeyDialog() async {
    final ctrl = TextEditingController(text: GeminiService.userKey ?? '');
    final isUserKey = GeminiService.isUserKey;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
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
                          child: Text(isUserKey ? 'Tersimpan di App' : 'Dari .env', style: TextStyle(fontSize: 10, color: isUserKey ? Colors.green.shade800 : Colors.black87))),
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
          );
        },
      ),
    );
  }

  // Custom drawer with full control (M3 spec: https://m3.material.io/components/navigation-drawer/overview)
  Widget _buildCustomDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(16))),
      child: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              const AiChatIcon(color: kAuthPrimary, size: 26, filled: true),
              const SizedBox(width: 10),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('FormUp AI', style: TextStyle(fontFamily: kFontBold, fontSize: 16, color: Colors.black87)),
                Text('Gemini 2.0 Flash', style: TextStyle(fontSize: 11, color: Colors.black54)),
              ]),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 22, color: Colors.black87),
                tooltip: 'Tutup',
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _newSession();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Chat baru'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(indent: 16, endIndent: 16, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
            child: Align(alignment: Alignment.centerLeft, child: Text('Riwayat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700, letterSpacing: 0.8))),
          ),
          Expanded(
            child: _sessions.isEmpty
                ? const Center(child: Text('Belum ada riwayat', style: TextStyle(fontSize: 12, color: Colors.black45)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: _sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (ctx, i) {
                      final s = _sessions[i];
                      final isSelected = s.id == _currentSessionId;
                      return Material(
                        color: isSelected ? kPrimary.withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            Navigator.pop(context);
                            await _switchSession(s.id);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(children: [
                              Icon(isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline, size: 16, color: isSelected ? kAuthPrimary : Colors.black54),
                              const SizedBox(width: 10),
                              Expanded(child: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isSelected ? kAuthPrimary : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
                              InkWell(
                                onTap: () async {
                                  final c = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Hapus chat?'), content: Text('Hapus "${s.title}"?'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Hapus'))]));
                                  if (c == true) await _deleteSession(s.id);
                                },
                                child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 14, color: Colors.black38)),
                              ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          // Bottom settings ala M3: https://m3.material.io/components/navigation-drawer/overview -> bottom area
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.settings_outlined, size: 24, color: Colors.black87),
                title: const Text('Pengaturan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(context);
                  // Buka screen setting AI (bukan bottom sheet) sesuai M3 nav drawer
                  AppRouter.of(context).push(AppPage.aiSettings);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, size: 24, color: Colors.red),
                title: const Text('Hapus semua riwayat', style: TextStyle(fontSize: 13)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Navigator.pop(context);
                  final c = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Hapus semua?'), content: const Text('Semua riwayat chat akan hilang.'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Hapus'))]));
                  if (c == true) {
                    await AiChatHistoryService.clearAll();
                    setState(() {
                      _messages.clear();
                      _sessions.clear();
                      _currentSessionId = null;
                    });
                    await _newSession();
                    if (mounted) showAuthToast(context, 'Semua history dihapus');
                  }
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hapus header atas (AppBar) -> pakai drawer M3 + top bar minimal di body
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kAppBg,
      drawer: _buildCustomDrawer(),
      body: Column(children: [
        // Header menyatu dengan background (tanpa card putih, tanpa tombol kanan)
        SafeArea(
          bottom: false,
          child: Container(
            color: kAppBg,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              if (widget.embedded)
                IconButton(icon: const Icon(Icons.menu, color: Colors.black87), onPressed: () => _scaffoldKey.currentState?.openDrawer())
              else
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => AppRouter.of(context).pop()),
              const AiChatIcon(color: kAuthPrimary, size: 20, filled: true),
              const SizedBox(width: 8),
              const Text('AI Chat', style: TextStyle(fontFamily: kFontBold, fontSize: 16, color: Colors.black87)),
            ]),
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: softShadow()),
                        child: const Icon(Icons.chat_bubble_outline, size: 40, color: kAuthPrimary),
                      ),
                      const SizedBox(height: 16),
                      const Text('Tanya AI untuk membuat form', style: TextStyle(fontFamily: kFontBold, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('Contoh: "Buatkan form kuis matematika 10 soal pilihan ganda tentang aljabar" atau "Edit form #12 tambahkan 5 soal essay"', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 16),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _QuickChip('Buat kuis 5 soal', () { _controller.text = 'Buatkan form kuis 5 soal pilihan ganda tentang sejarah Indonesia'; _send(); }),
                        _QuickChip('Form survey', () { _controller.text = 'Buatkan form survey kepuasan pelanggan 7 pertanyaan'; _send(); }),
                        _QuickChip('Edit form', () { _controller.text = 'Tambahkan 3 soal essay ke form terakhir saya'; _send(); }),
                      ]),
                    ]),
                  ),
                )
              : ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: _messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final m = _messages[i];
                    final isUser = m.role == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.82),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser ? kAuthPrimary : Colors.white,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isUser ? const Radius.circular(4) : null,
                            bottomLeft: !isUser ? const Radius.circular(4) : null,
                          ),
                          boxShadow: softShadow(),
                          border: isUser ? null : Border.all(color: const Color(0xFFBDC9C8)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (!isUser && _streaming && i == _messages.length - 1 && m.text.isEmpty)
                            const Row(children: [SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('AI mengetik...', style: TextStyle(fontSize: 11, color: Colors.black54))])
                          else
                            SelectableText(m.text.isEmpty ? '...' : m.text, style: TextStyle(fontSize: 13, color: isUser ? Colors.white : Colors.black87)),
                          if (m.actionJson != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: isUser ? Colors.white24 : const Color(0xFFF0F4F4), borderRadius: BorderRadius.circular(8)),
                              child: Row(children: [
                                Icon(m.actionExecuted ? Icons.check_circle : Icons.auto_awesome, size: 14, color: m.actionExecuted ? Colors.green : Colors.black54),
                                const SizedBox(width: 6),
                                Expanded(child: Text('Aksi: ${m.actionJson!['action']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isUser ? Colors.white : Colors.black87))),
                                if (!m.actionExecuted && !isUser)
                                  TextButton(
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                                    onPressed: () async {
                                      try {
                                        await _executeAction(m.actionJson!);
                                        setState(() { m.actionExecuted = true; m.actionResult = 'Berhasil'; });
                                        showAuthToast(context, 'Berhasil');
                                        await _persistCurrent();
                                      } catch (e) {
                                        setState(() => m.actionResult = 'Gagal: $e');
                                        showAuthToast(context, '$e', isError: true);
                                      }
                                    },
                                    child: const Text('Jalankan', style: TextStyle(fontSize: 11)),
                                  ),
                              ]),
                            ),
                            if (m.actionResult != null)
                              Padding(padding: const EdgeInsets.only(top: 4), child: Text(m.actionResult!, style: TextStyle(fontSize: 11, color: m.actionResult!.startsWith('Gagal') ? Colors.red : Colors.green))),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: kAppBg,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: _streaming ? 'AI sedang menjawab...' : 'Ketik pesan...',
                    filled: true,
                    fillColor: const Color(0xFFF0F4F4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                  enabled: !_streaming,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _streaming ? null : _send,
                style: FilledButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(12), backgroundColor: kAuthPrimary),
                child: _streaming
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, size: 18, color: Colors.white),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip(this.label, this.onTap);
  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label, style: const TextStyle(fontSize: 12)), onPressed: onTap, backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFBDC9C8))));
  }
}
