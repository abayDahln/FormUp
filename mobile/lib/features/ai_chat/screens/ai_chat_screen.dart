import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:form_up/core/services/ai_chat_history_service.dart';
import 'package:form_up/core/services/ai_form_context_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/gemini_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/ai_chat_icon.dart';
import 'package:form_up/features/ai_chat/widgets/ai_model_picker.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Controller dengan highlight background untuk teks @mention.
class MentionHighlightController extends TextEditingController {
  /// Token mention aktif (tanpa '@'), di-set dari state screen.
  List<String> mentionTokens = [];

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (mentionTokens.isEmpty) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final spans = <InlineSpan>[];
    var remaining = text;
    while (remaining.isNotEmpty) {
      int? best;
      String? bestTok;
      for (final t in mentionTokens) {
        final i = remaining.indexOf(t);
        if (i != -1 && (best == null || i < best)) {
          best = i;
          bestTok = t;
        }
      }
      if (best == null || bestTok == null) break;
      if (best > 0) spans.add(TextSpan(text: remaining.substring(0, best)));
      spans.add(TextSpan(
        text: remaining.substring(best, best + bestTok.length),
        style: (style ?? const TextStyle()).merge(const TextStyle(
          backgroundColor: Color(0x298FB5B3), // teal lembut ~16%
          color: Color(0xFF018081),
          fontWeight: FontWeight.w600,
        )),
      ));
      remaining = remaining.substring(best + bestTok.length);
    }
    if (remaining.isNotEmpty) spans.add(TextSpan(text: remaining));
    return TextSpan(style: style, children: spans);
  }
}

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
  final _controller = MentionHighlightController();
  final _scroll = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];
  String? _currentSessionId;
  bool _streaming = false;
  StreamSubscription<String>? _sub;
  static bool _shownInitialMissingKeyToast = false;

  // Agent: @mention & model picker
  List<FormData> _allForms = [];
  List<FormData> _mentionCandidates = [];
  String _mentionQuery = '';
  int _mentionStart = -1;
  bool _isMentionActive = false;
  // id -> label yang tampil di text field (dipotong 1-2 kata)
  final Map<int, String> _pickedMentions = {};
  String _lastText = '';
  // FAB scroll-to-bottom: muncul jika user sudah scroll ke atas > 1 layar & belum di paling bawah
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _scroll.addListener(_onScroll);
    _loadSessions();
    _loadAllForms();
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

  bool _isLoadingForms = false;
  bool _formsLoadFailed = false;
  String? _formsLoadError;

  Future<void> _loadAllForms({bool force = false}) async {
    if (_isLoadingForms) return;
    // jika sebelumnya gagal, jangan retry terus — hanya retry saat dipaksa (ketik '@' lagi)
    if (_formsLoadFailed && !force) return;
    _isLoadingForms = true;
    _formsLoadFailed = false;
    try {
      final forms = await FormService.getMyForms();
      _formsLoadError = null;
      if (mounted) setState(() => _allForms = forms);
    } catch (e) {
      _formsLoadFailed = true;
      _formsLoadError = AuthService.errorMessage(e);
      debugPrint('[AiChat] Gagal memuat daftar form untuk mention: $e');
      if (mounted) setState(() {});
    } finally {
      _isLoadingForms = false;
      // re-evaluasi kandidat setelah forms selesai dimuat
      if (mounted && _isMentionActive) _onTextChanged();
    }
  }

  /// Tampilkan pesan error apa adanya (membongkar prefix "Exception: ")
  /// supaya pesan asli dari Gemini (mis. "Not Found", "API key not valid") terlihat jelas.
  String _friendlyError(Object e) {
    var s = e.toString();
    if (s.startsWith('Exception: ')) s = s.substring('Exception: '.length);
    return s;
  }

  /// Label mention pendek: maksimal 2 kata pertama, lalu dipotong dengan "..."
  String _mentionLabel(FormData f) {
    final words = f.title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'form';
    var s = words.take(2).join(' ');
    if (words.length > 2) s = '$s...';
    if (s.length > 20) s = '${s.substring(0, 17)}...';
    return s;
  }

  void _onTextChanged() {
    final text = _controller.text;
    final prev = _lastText;
    _lastText = text;
    // sinkronkan token highlight
    _controller.mentionTokens = _pickedMentions.values.where((l) => text.contains('@$l')).toList();
    // buang picked yang tokennya sudah tidak ada di teks (mis. select-all delete / cut)
    if (_pickedMentions.isNotEmpty) {
      final stale = _pickedMentions.keys.where((id) => !text.contains('@${_pickedMentions[id]}')).toList();
      if (stale.isNotEmpty) {
        setState(() { for (final id in stale) { _pickedMentions.remove(id); } });
      }
    }

    // Backspace: jika 1 karakter dihapus dan karakter itu ada di dalam token mention,
    // hapus seluruh mention sekaligus (alasan: "@label" yang sebagian tidak bermakna)
    if (text.length == prev.length - 1 && _pickedMentions.isNotEmpty) {
      final sel = _controller.selection;
      final removedAt = sel.isValid && sel.baseOffset >= 0 ? sel.baseOffset : -1;
      if (removedAt >= 0) {
        for (final entry in _pickedMentions.entries) {
          final token = '@${entry.value}';
          final idx = prev.indexOf(token);
          if (idx != -1 && removedAt > idx && removedAt <= idx + token.length) {
            var end = idx + token.length;
            if (end < prev.length && prev[end] == ' ') end++;
            final newText = prev.substring(0, idx) + prev.substring(end);
            setState(() {
              _pickedMentions.remove(entry.key);
              _lastText = newText;
              _controller.mentionTokens = _pickedMentions.values.where((l) => newText.contains('@$l')).toList();
            });
            _controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: idx.clamp(0, newText.length)),
            );
            return;
          }
        }
      }
    }

    final sel = _controller.selection;
    if (!sel.isValid || sel.baseOffset < 0) {
      if (_isMentionActive) setState(() { _isMentionActive = false; _mentionCandidates = []; });
      return;
    }
    final cursor = sel.baseOffset;
    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');
    if (atIndex == -1) {
      if (_isMentionActive) setState(() { _isMentionActive = false; _mentionCandidates = []; });
      return;
    }
    // jika ada spasi/newline antara @ dan cursor dengan jarak > 30, anggap bukan mention
    final query = before.substring(atIndex + 1);
    if (query.contains(' ') || query.contains('\n') || query.length > 30) {
      if (_isMentionActive) setState(() { _isMentionActive = false; _mentionCandidates = []; });
      return;
    }
    // valid mention query — '@' saja tampilkan semua, '@pemrograman' filter, tooltip scrollable
    _mentionStart = atIndex;
    _mentionQuery = query.toLowerCase();
    _isMentionActive = true;
    // refresh forms jika kosong (user baru buat form) — force retry saat user mengetik '@' lagi
    if (_allForms.isEmpty && !_isLoadingForms) {
      _loadAllForms(force: _formsLoadFailed);
    }
    final candidates = _allForms.where((f) {
      final t = f.title.toLowerCase();
      return _mentionQuery.isEmpty || t.contains(_mentionQuery);
    }).toList();
    setState(() => _mentionCandidates = candidates);
  }

  void _selectMention(FormData form) {
    if (_mentionStart < 0 || _mentionStart >= _controller.text.length) return;
    final text = _controller.text;
    final cursor = _controller.selection.isValid && _controller.selection.baseOffset >= 0
        ? _controller.selection.baseOffset
        : text.length;
    final before = text.substring(0, _mentionStart);
    final after = cursor <= text.length ? text.substring(cursor) : '';
    final mention = '@${_mentionLabel(form)} ';
    final newText = '$before$mention$after';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: (before + mention).length),
    );
    _lastText = newText;
    _controller.mentionTokens = [..._controller.mentionTokens, _mentionLabel(form)];
    _pickedMentions[form.id] = _mentionLabel(form);
    setState(() { _mentionCandidates = []; _isMentionActive = false; });
  }

  List<int> _extractMentionIds(String text) {
    // Deteksi via picked ids yang masih ada di text (pakai label pendek), fallback scan label judul
    final ids = <int>[];
    for (final entry in _pickedMentions.entries) {
      if (text.contains('@${entry.value}')) ids.add(entry.key);
    }
    // fallback: hanya match '@label' persis, jangan judul polos (hindari konteks palsu)
    if (ids.isEmpty && text.contains('@')) {
      for (final f in _allForms) {
        if (text.contains('@${_mentionLabel(f)}')) {
          ids.add(f.id);
          if (ids.length >= 3) break;
        }
      }
    }
    return ids.toSet().toList();
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
    // Langsung tampilkan chat terbaru (paling bawah) saat ganti sesi
    _showFab = false;
    _scrollToBottom(immediate: true);
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
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scroll.dispose();
    _sub?.cancel();
    super.dispose();
  }

  /// Listener scroll: kontrol visibilitas FAB scroll-to-bottom.
  /// Muncul jika sudah scroll melebihi 1 layar dari atas & belum di paling bawah.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final show = pos.viewportDimension > 0 &&
        _scroll.offset > pos.viewportDimension &&
        _scroll.offset < pos.maxScrollExtent - 32;
    if (show != _showFab && mounted) setState(() => _showFab = show);
  }

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (immediate) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(target, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
      }
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
    final rawText = _controller.text.trim();
    if (rawText.isEmpty || _streaming) return;
    if (!GeminiService.hasKey) {
      showAuthToast(context, 'GEMINI_API_KEY belum diatur', isError: true);
      _showApiKeyDialog();
      return;
    }
    // ensure session exists
    if (_currentSessionId == null) await _newSession();
    // Agent: deteksi @mention dan bangun konteks form
    final mentionIds = _extractMentionIds(rawText);
    String? extraContext;
    if (mentionIds.isNotEmpty) {
      try {
        extraContext = await AiFormContextService.buildContext(mentionIds);
      } catch (_) {}
    } else if (rawText.toLowerCase().contains('form saya') || rawText.toLowerCase().contains('list form') || rawText.toLowerCase().contains('daftar form')) {
      try {
        extraContext = await AiFormContextService.buildAllFormsSummary();
      } catch (_) {}
    }
    final displayText = rawText;
    final sendText = extraContext != null && extraContext.isNotEmpty ? '$extraContext\n\nPertanyaan user: $rawText' : rawText;
    // bersihkan mention picker
    setState(() {
      _mentionCandidates = [];
      _isMentionActive = false;
      _pickedMentions.clear(); // jangan bawa mention pesan sebelumnya ke pesan berikutnya
    });

    final userMsg = ChatMessage(role: 'user', text: displayText);
    setState(() {
      _messages.add(userMsg);
      _controller.clear();
    });
    _scrollToBottom();
    await _persistCurrent();

    // history yang dikirim ke AI pakai sendText untuk pesan terakhir, tapi simpan displayText
    final history = _messages.map((m) {
      if (m == userMsg && sendText != displayText) {
        return {'role': m.role, 'text': sendText};
      }
      return {'role': m.role, 'text': m.text};
    }).toList();
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
              botMsg.text = 'Error: ${_friendlyError(e)}';
              _streaming = false;
            });
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      setState(() {
        botMsg.text = 'Error: ${_friendlyError(e)}';
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
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('FormUp AI', style: TextStyle(fontFamily: kFontBold, fontSize: 16, color: Colors.black87)),
                Text(GeminiService.selectedModelDisplay, style: const TextStyle(fontSize: 11, color: Colors.black54)),
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kAppBg, kAppBg.withValues(alpha: 0.75), kAppBg.withValues(alpha: 0)],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              if (widget.embedded)
                IconButton(icon: const Icon(Icons.menu, color: Colors.black87), onPressed: () => _scaffoldKey.currentState?.openDrawer())
              else
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => AppRouter.of(context).pop()),
              const AiChatIcon(color: kAuthPrimary, size: 20, filled: true),
              const SizedBox(width: 8),
              const Text('AI Chat', style: TextStyle(fontFamily: kFontBold, fontSize: 16, color: Colors.black87)),
              const Spacer(),
              AiModelPicker(onChanged: () => setState(() {})),
            ]),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              if (_messages.isEmpty)
                Center(
                  child: SingleChildScrollView(
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
              else
                ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
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
                            isUser
                                ? SelectableText(m.text.isEmpty ? '...' : m.text, style: const TextStyle(fontSize: 13, color: Colors.white))
                                // Render jawaban AI sebagai markdown (bold, list, tabel, code block, LaTeX)
                                : GptMarkdown(
                                    m.text.isEmpty ? '...' : m.text,
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
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
                                        if (context.mounted) showAuthToast(context, 'Berhasil');
                                        await _persistCurrent();
                                      } catch (e) {
                                        setState(() => m.actionResult = 'Gagal: $e');
                                        if (context.mounted) showAuthToast(context, '$e', isError: true);
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
              // Footer overlay: gradient memudar dari transparan ke kAppBg (chat terlihat fade di bawahnya)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [kAppBg.withValues(alpha: 0), kAppBg.withValues(alpha: 0.9), kAppBg],
                      stops: const [0.0, 0.35, 1.0],
                    ),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
        // @mention autocomplete — tooltip scrollable berisi semua form, filter saat "@pemrograman"
        if (_isMentionActive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Material(
              color: Colors.white,
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFBDC9C8))),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: _mentionCandidates.isEmpty
                ? InkWell(
                    onTap: _formsLoadFailed ? () => _loadAllForms(force: true) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(children: [
                        Icon(
                          _formsLoadFailed ? Icons.error_outline : Icons.search_off,
                          size: 16,
                          color: _formsLoadFailed ? Colors.red : Colors.black45,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formsLoadFailed
                                ? 'Gagal memuat form: $_formsLoadError — ketuk untuk coba lagi'
                                : _isLoadingForms
                                    ? 'Memuat form...'
                                    : _mentionQuery.isEmpty
                                        ? 'Kamu belum punya form'
                                        : 'Tidak ada form dengan judul "@$_mentionQuery"',
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ),
                      ]),
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    child: ListView.separated(
                      shrinkWrap: true,
                      primary: false,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _mentionCandidates.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 12, endIndent: 12),
                      itemBuilder: (ctx, i) {
                        final f = _mentionCandidates[i];
                        return ListTile(
                          dense: true,
                          leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: kPrimarySoft, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.description_outlined, size: 14, color: kAuthPrimary)),
                          title: Text(f.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          subtitle: Text('#${f.id} • ${f.status}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          onTap: () => _selectMention(f),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        // Hint untuk @mention (ketika tidak aktif)
        if (!_isMentionActive && _controller.text.contains('@'))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              const Icon(Icons.alternate_email, size: 12, color: Colors.black45),
              const SizedBox(width: 6),
              Expanded(child: Text(_pickedMentions.isEmpty ? 'Ketik @ untuk mention form' : 'Mention: ${_pickedMentions.length} form terpilih', style: const TextStyle(fontSize: 10, color: Colors.black54))),
              if (_pickedMentions.isNotEmpty)
                GestureDetector(onTap: () => setState(() { _pickedMentions.clear(); _controller.mentionTokens = []; }), child: const Text('Hapus', style: TextStyle(fontSize: 10, color: Colors.red))),
            ]),
          ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      enabled: !_streaming,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _streaming ? 'AI sedang menjawab...' : 'Ketik @ untuk mention form...',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.black45),
                        // Tombol send menyatu di dalam field (kanan)
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            onPressed: _streaming ? null : _send,
                            style: IconButton.styleFrom(backgroundColor: kAuthPrimary, foregroundColor: Colors.white),
                            iconSize: 18,
                            icon: _streaming
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.arrow_upward),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                  ]),
                ),
              ),
              // FAB scroll-to-chat-terbaru (muncul saat user jauh di atas, hilang di paling bawah)
              Positioned(
                right: 16,
                bottom: 170,
                child: IgnorePointer(
                  ignoring: !_showFab,
                  child: AnimatedOpacity(
                    opacity: _showFab ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: FloatingActionButton.small(
                      heroTag: 'aiChatScrollToBottom',
                      backgroundColor: Colors.white,
                      foregroundColor: kAuthPrimary,
                      elevation: 3,
                      onPressed: () => _scrollToBottom(),
                      child: const Icon(Icons.arrow_downward, size: 20),
                    ),
                  ),
                ),
              ),
            ],
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
