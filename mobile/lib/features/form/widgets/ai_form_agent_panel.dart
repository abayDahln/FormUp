import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/ai_form_agent_history_service.dart';
import 'package:form_up/core/services/gemini_service.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/ai_chat_icon.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/ai_chat/controllers/ai_voice_recorder.dart';
import 'package:form_up/features/ai_chat/models/ai_attachment.dart';
import 'package:form_up/features/ai_chat/utils/ai_attachment_picker.dart';
import 'package:form_up/features/ai_chat/widgets/ai_model_picker.dart';
import 'package:form_up/features/ai_chat/widgets/api_key_dialog.dart';
import 'package:form_up/features/ai_chat/widgets/chat_bubble.dart';
import 'package:form_up/features/ai_chat/widgets/chat_input_bar.dart';
import 'package:form_up/features/form/controllers/form_maker_controller.dart';

/// Satu pesan di panel AFA (view-model in-memory). Lampiran membawa bytes
/// agar pratinjau gambar tetap bisa dibuka; versi persist memakai
/// [FormAgentMessage] yang hanya menyimpan metadata lampiran.
class _AgentMsg {
  final bool isUser;
  final String text;

  /// Ringkasan perubahan draf yang diterapkan pada pesan ini.
  final List<String> applied;
  final bool isError;
  List<AiAttachment> attachments;

  _AgentMsg({
    required this.isUser,
    required this.text,
    this.applied = const [],
    this.isError = false,
    this.attachments = const [],
  });
}

/// Panel **AFA (AI Form Agent)** — versi mini dari layar AI Chat (gaya
/// Gemini), hidup di layar edit form (sidebar tablet/desktop, overlay di HP).
///
/// Struktur visual menyamai `AiChatScreen`: chat full-bleed dengan gradient
/// atas (baris konteks form + tombol riwayat/tutup) dan bawah, pill prompt
/// melayang dua baris dengan pemilih model DI DALAM pill, serta drawer
/// riwayat & pengaturan yang meluncur dari kanan (pola `AiChatDrawer`).
///
/// Sama seperti AI Chat: bubble + lampiran + rekam suara + ganti model +
/// API key yang sama. Bedanya:
/// - Fokus HANYA pada form yang sedang dibuka (tanpa sintaks '@').
/// - Perubahan **langsung diterapkan** ke draf lokal (tanpa dialog terima),
///   karena draf tetap milik user dan server hanya tersentuh saat Simpan.
/// - Riwayat percakapan sendiri per form ([AiFormAgentHistoryService]),
///   terpisah dari riwayat AI Chat umum.
class AiFormAgentPanel extends StatefulWidget {
  /// Form yang sedang dibuka; null = draf baru (belum punya id).
  final int? formId;

  /// Akses controller pengaturan (judul/deskripsi) draf; null bila layar ini
  /// tidak punya kartu pengaturan (mis. layar kelola soal di HP).
  final FormMakerController? Function()? settings;

  /// Daftar draf soal aktif (referensi langsung — dimutasi di tempat);
  /// null bila layar ini tidak punya daftar soal.
  final List<QuestionDraft> Function()? questions;

  /// Memberi tahu screen agar rebuild setelah draf diubah.
  final void Function() onChanged;

  /// Menutup panel (null = tidak ada tombol tutup, mis. dipakai sebagai
  /// kartu penuh di sidebar).
  final VoidCallback? onClose;

  const AiFormAgentPanel({
    super.key,
    required this.formId,
    this.settings,
    this.questions,
    required this.onChanged,
    this.onClose,
  });

  @override
  State<AiFormAgentPanel> createState() => AiFormAgentPanelState();
}

class AiFormAgentPanelState extends State<AiFormAgentPanel> {
  final List<_AgentMsg> _messages = [];
  final TextEditingController _input = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scroll = ScrollController();
  final AiVoiceRecorder _voice = AiVoiceRecorder();

  List<AiAttachment> _pendingAttachments = [];
  List<FormAgentSession> _sessions = [];
  String? _currentSessionId;
  bool _busy = false;

  /// True = drawer riwayat & pengaturan meluncur menutupi chat.
  bool _drawerOpen = false;

  /// Tinggi pill prompt terukur (membesar saat multiline / ada lampiran) —
  /// padding list & gradient bawah mengikuti, pola yang sama dengan
  /// `AiChatScreen._inputBarHeight`.
  double _inputBarHeight = 104;
  final _inputBarKey = GlobalKey();

  /// Tinggi baris atas (chip konteks + tombol) — konstanta; dipakai untuk
  /// padding atas list & empty state (gradient baris atas ±64px).
  static const double _topBarHeight = 64;

  /// Riwayat disimpan per form: draf baru memakai key 'draft' hingga form
  /// punya id (lihat didUpdateWidget).
  int? _historyFormId;

  @override
  void initState() {
    super.initState();
    _historyFormId = widget.formId;
    _loadSessions();
  }

  @override
  void didUpdateWidget(covariant AiFormAgentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Form baru tersimpan (draf → punya id): pindahkan riwayat ke key form
    // agar percakapan yang sudah ada tidak hilang / tidak tercampur.
    if (widget.formId != oldWidget.formId) {
      final previous = _historyFormId;
      _historyFormId = widget.formId;
      if (previous == null && widget.formId != null) {
        AiFormAgentHistoryService.migrateDraftToForm(
          widget.formId!,
        ).then((_) => _loadSessions());
      } else {
        _loadSessions();
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _focusNode.dispose();
    _scroll.dispose();
    _voice.dispose();
    super.dispose();
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // --- Sesi (riwayat per form) ---

  Future<void> _loadSessions() async {
    final all = await AiFormAgentHistoryService.loadSessions(_historyFormId);
    if (!mounted) return;
    setState(() => _sessions = all);
    if (all.isEmpty) {
      setState(() => _currentSessionId = _newId());
      return;
    }
    // Lanjutkan sesi terakhir form ini (riwayat tetap tersimpan).
    await _switchSession(all.first.id);
  }

  Future<void> _newSession() async {
    if (_busy) return;
    if (_messages.isEmpty) {
      if (_sessions.isNotEmpty && mounted) {
        showAuthToast(context, 'Chat masih kosong');
      }
      setState(() {
        _currentSessionId = _newId();
        _messages.clear();
        _pendingAttachments = [];
        _drawerOpen = false;
      });
      return;
    }
    setState(() {
      _currentSessionId = _newId();
      _messages.clear();
      _pendingAttachments = [];
      _drawerOpen = false;
    });
  }

  Future<void> _switchSession(String id) async {
    if (id == _currentSessionId) {
      if (mounted) setState(() => _drawerOpen = false);
      return;
    }
    final all = await AiFormAgentHistoryService.loadSessions(_historyFormId);
    final idx = all.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    final restored = <_AgentMsg>[];
    for (final m in all[idx].messages) {
      restored.add(await _fromHistory(m));
    }
    if (!mounted) return;
    setState(() {
      _currentSessionId = id;
      _messages
        ..clear()
        ..addAll(restored);
      _pendingAttachments = [];
      _drawerOpen = false;
    });
    _scrollToEnd();
  }

  Future<void> _deleteSession(String id) async {
    await AiFormAgentHistoryService.delete(_historyFormId, id);
    final all = await AiFormAgentHistoryService.loadSessions(_historyFormId);
    if (!mounted) return;
    setState(() => _sessions = all);
    if (_currentSessionId != id) return;
    if (all.isEmpty) {
      setState(() {
        _messages.clear();
        _currentSessionId = _newId();
      });
    } else {
      await _switchSession(all.first.id);
    }
  }

  Future<void> _clearAllSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text(
          'Hapus semua riwayat?',
          style: TextStyle(fontFamily: kFontBold),
        ),
        content: const Text(
          'Riwayat percakapan AFA untuk form ini akan dihapus. '
          'Draf form & soal tidak terpengaruh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AiFormAgentHistoryService.clearAll(_historyFormId);
    if (!mounted) return;
    setState(() {
      _sessions.clear();
      _messages.clear();
      _pendingAttachments.clear();
      _currentSessionId = _newId();
      _drawerOpen = false;
    });
  }

  Future<void> _confirmDeleteSession(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text(
          'Hapus chat?',
          style: TextStyle(fontFamily: kFontBold),
        ),
        content: Text('Hapus "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteSession(id);
  }

  /// Konversi pesan persist → view-model (bytes lampiran dimuat dari disk).
  Future<_AgentMsg> _fromHistory(FormAgentMessage m) async {
    final atts = <AiAttachment>[];
    for (final meta in m.attachments ?? const <Map<String, dynamic>>[]) {
      final a = AiAttachment.tryFromMeta(meta);
      if (a == null) continue;
      await a.reloadBytes();
      atts.add(a);
    }
    return _AgentMsg(
      isUser: m.isUser,
      text: m.text,
      applied: m.applied,
      isError: m.isError,
      attachments: atts,
    );
  }

  FormAgentMessage _toHistory(_AgentMsg m) => FormAgentMessage(
    isUser: m.isUser,
    text: m.text,
    applied: m.applied,
    isError: m.isError,
    attachments: m.attachments.isEmpty
        ? null
        : m.attachments.map((a) => a.toMetaJson()).toList(),
  );

  /// Simpan sesi aktif. Bytes lampiran disimpan ke disk sekali agar pratinjau
  /// tetap ada setelah restart (metadata saja tidak membawa bytes).
  Future<void> _persistSession() async {
    final id = _currentSessionId;
    if (id == null || _messages.isEmpty) return;
    for (final m in _messages) {
      for (final a in m.attachments) {
        if (a.hasBytes && (a.filePath == null || a.filePath!.isEmpty)) {
          final p = await AiAttachment.saveToDisk(a);
          if (p != null) a.filePath = p;
        }
      }
    }
    final history = [for (final m in _messages) _toHistory(m)];
    await AiFormAgentHistoryService.upsert(
      _historyFormId,
      FormAgentSession(
        id: id,
        title: AiFormAgentHistoryService.titleFor(history),
        messages: history,
        updatedAt: DateTime.now(),
      ),
    );
    final all = await AiFormAgentHistoryService.loadSessions(_historyFormId);
    if (mounted) setState(() => _sessions = all);
  }

  // --- Kirim & terapkan aksi ---

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final attachments = List<AiAttachment>.of(_pendingAttachments);
    if ((text.isEmpty && attachments.isEmpty) || _busy) return;

    if (!GeminiService.hasKey) {
      setState(() {
        _messages.add(
          _AgentMsg(
            isUser: false,
            text:
                'API key Gemini belum diatur. Ketuk ikon menu di kanan atas, '
                'lalu Pengaturan untuk mengaturnya.',
            isError: true,
          ),
        );
      });
      _scrollToEnd();
      return;
    }

    _currentSessionId ??= _newId();
    _input.clear();
    setState(() {
      _messages.add(
        _AgentMsg(isUser: true, text: text, attachments: attachments),
      );
      _pendingAttachments = [];
      _busy = true;
    });
    _scrollToEnd();

    try {
      final history = <Map<String, String>>[
        for (final m in _messages)
          {
            'role': m.isUser ? 'user' : 'model',
            'text': m.text.isEmpty && m.attachments.isNotEmpty
                ? '(lampiran)'
                : m.text,
          },
      ];
      final raw = await GeminiService.generateOnce(
        history,
        inlineAttachments: attachments.isEmpty ? null : attachments,
        // Kontrak AFA menggantikan prompt AI Chat umum — tanpa ini dua
        // skema JSON bertabrakan dan balasan sering tak terbaca.
        systemInstruction: _systemInstruction(),
      );
      final parsed = _extractJson(raw);
      if (!mounted) return;

      if (parsed == null) {
        setState(() {
          _busy = false;
          _messages.add(
            _AgentMsg(
              isUser: false,
              text: 'Balasan AFA tidak dapat dibaca. Coba lagi.',
              isError: true,
            ),
          );
        });
        await _persistSession();
        _scrollToEnd();
        return;
      }

      final applied = _applyActions(parsed['actions'] as List<dynamic>? ?? []);
      final reply = (parsed['reply'] as String?)?.trim();
      setState(() {
        _busy = false;
        _messages.add(
          _AgentMsg(
            isUser: false,
            text: reply == null || reply.isEmpty
                ? (applied.isEmpty
                      ? 'Tidak ada perubahan pada draf.'
                      : 'Draf diperbarui.')
                : reply,
            applied: applied,
          ),
        );
      });
      if (applied.isNotEmpty) widget.onChanged();
      await _persistSession();
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messages.add(
          _AgentMsg(
            isUser: false,
            text: GeminiService.friendlyMessage(e),
            isError: true,
          ),
        );
      });
      await _persistSession();
      _scrollToEnd();
    }
  }

  /// Instruksi sistem AFA: kontrak JSON aksi + kemampuan yang aktif + snapshot
  /// draf terkini. Dikirim lewat `systemInstruction` agar tidak tercampur
  /// dengan skema AI Chat umum.
  String _systemInstruction() {
    final s = widget.settings?.call();
    final questions = widget.questions?.call();
    final hasSettings = s != null;
    final hasQuestions = questions != null;

    final actions = <String>[
      if (hasSettings) '- {"type":"set_title","value":"..."}',
      if (hasSettings) '- {"type":"set_description","value":"..."}',
      if (hasQuestions)
        '- {"type":"add_question","question":{"typeId":1|2|3|4|5,"text":"...","options":["A","B"],"correctAnswer":"A","isRequired":true,"points":10}}',
      if (hasQuestions)
        '- {"type":"update_question","index":0,"text":"...","typeId":2,"options":["A","B"],"correctAnswer":"B","isRequired":false,"points":null}',
      if (hasQuestions) '- {"type":"delete_question","index":1}',
      if (hasQuestions) '- {"type":"clear_questions"}',
    ];
    final capability = <String>[
      if (hasSettings) 'pengaturan form (judul & deskripsi)',
      if (hasQuestions) 'daftar soal (tambah/ubah/hapus)',
    ];

    return '''
Kamu adalah "AFA" (AI Form Agent) di aplikasi FormUp. Kamu bekerja HANYA pada form
yang sedang dibuka user: form ini otomatis menjadi konteks percakapan — user TIDAK
memakai sintaks '@' dan kamu tidak boleh mengubah, mencari, atau menyebut form lain
(teks yang mengandung '@' diperlakukan sebagai teks biasa). Jika user menyebut form
lain, tolak dengan sopan di "reply" dan kirim "actions": [].

Balas HANYA satu objek JSON valid (tanpa markdown/penjelasan di luar JSON):
{"reply":"penjelasan singkat dalam Bahasa Indonesia","actions":[...]}

${actions.isEmpty ? 'Tidak ada aksi yang tersedia saat ini.' : 'Aksi yang tersedia:\n${actions.join('\n')}'}
${capability.isEmpty ? 'Kamu tidak bisa mengubah draf apa pun saat ini — jawab pertanyaan user saja dengan "actions": [].' : 'Bagian draf yang BISA kamu ubah saat ini: ${capability.join(' dan ')}.'}
Jika user meminta perubahan pada bagian yang TIDAK tersedia, tolak dengan sopan di
"reply", kirim "actions": [], dan jelaskan singkat bahwa bagian itu diubah dari layar lain.

Aturan:
- typeId: 1=Essay, 2=Pilihan Ganda (min 2 opsi, tepat 1 kunci), 3=Checkbox
  (boleh >1 kunci, correctAnswer "A,C"), 4=Tanggal & Waktu (tanpa skor),
  5=Benar/Salah (correctAnswer "Benar" atau "Salah").
- index mengacu ke nomor soal pada DRAF SAAT INI (0-based, sesuai urutan).
- Pertahankan soal yang tidak diminta diubah — kirim aksi hanya untuk yang
  berubah, ditambah add_question untuk soal baru.
- Lampiran dari user (gambar/dokumen) bisa kamu baca — jadikan sumber isi soal
  bila user memintanya (mis. "buatkan soal dari gambar ini").
- Jika permintaan tidak butuh perubahan, kirim "actions": [].

DRAF SAAT INI:
${_draftSnapshot(s, questions)}''';
  }

  /// Snapshot draf lokal (hanya bagian yang tersedia di layar ini).
  String _draftSnapshot(
    FormMakerController? s,
    List<QuestionDraft>? questions,
  ) {
    final data = <String, dynamic>{};
    if (s != null) {
      data['judul'] = s.titleController.text.trim();
      data['deskripsi'] = s.descController.document.toPlainText().trim();
    }
    if (questions != null) {
      data['jumlah_soal'] = questions.length;
      data['soal'] = [
        for (var i = 0; i < questions.length; i++)
          {
            'index': i,
            'typeId': questions[i].typeId,
            'tipe': questionTypes[questions[i].typeId]?.$1 ?? '',
            'text': questions[i].question.document.toPlainText().trim(),
            'options': [
              for (final o in questions[i].options)
                o.text.document.toPlainText().trim(),
            ],
            'correctAnswer': questions[i].correctAnswer.text.trim(),
            'isRequired': questions[i].isRequired,
            'points': questions[i].points,
          },
      ];
    }
    if (data.isEmpty) return '(tidak ada draf yang bisa dibaca)';
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Map<String, dynamic>? _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(raw.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  int _typeIdFrom(dynamic v) {
    if (v is num) {
      final id = v.toInt();
      if (questionTypes.containsKey(id)) return id;
    }
    final s = v?.toString().toLowerCase().trim() ?? '';
    if (s.contains('checkbox')) return 3;
    if (s.contains('benar') || s.contains('true') || s.contains('false')) {
      return 5;
    }
    if (s.contains('tanggal') || s.contains('waktu') || s.contains('date')) {
      return 4;
    }
    if (s.contains('ganda') || s.contains('pilihan') || s.contains('mc')) {
      return 2;
    }
    return 1; // default essay
  }

  /// Tandai opsi benar dari kunci bebas ("A", "B. teks", teks persis, "A,C").
  void _markCorrect(QuestionDraft q, String key) {
    final parts = key
        .split(RegExp(r'[,|;]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    for (var i = 0; i < q.options.length; i++) {
      final text = q.options[i].text.document.toPlainText().trim();
      var match = false;
      for (final p in parts) {
        if (text.toLowerCase() == p.toLowerCase()) match = true;
        if (p.length == 1) {
          final c = p.toUpperCase().codeUnitAt(0);
          if (c >= 65 && c <= 69 && c - 65 == i) match = true;
        }
        final num = int.tryParse(p);
        if (num != null && num == i + 1) match = true;
      }
      q.options[i].isCorrect = match;
    }
  }

  void _fillOptions(QuestionDraft q, List<dynamic> raw, String key) {
    for (final o in q.options) {
      o.text.dispose();
    }
    q.options.clear();
    for (final o in raw) {
      final text = o is Map
          ? (o['text'] ?? o['optionText'] ?? '').toString()
          : o.toString();
      if (text.trim().isEmpty) continue;
      q.options.add(OptionDraft(text: text.trim()));
    }
    if (key.isNotEmpty && q.options.isNotEmpty) _markCorrect(q, key);
  }

  /// Draf soal baru hasil aksi add_question.
  QuestionDraft _draftFrom(Map<String, dynamic> j) {
    final typeId = _typeIdFrom(j['typeId'] ?? j['tipe'] ?? j['type']);
    final key = (j['correctAnswer'] ?? j['kunci'] ?? '').toString().trim();
    final options = (j['options'] ?? j['opsi']);
    final draft = QuestionDraft(
      typeId,
      question: (j['text'] ?? j['question'] ?? '').toString(),
      correctAnswer: key,
      isRequired: j['isRequired'] as bool? ?? true,
      points: j['points'] is num ? (j['points'] as num).toInt() : null,
    );
    if (draft.hasOptions && options is List) {
      _fillOptions(draft, options, key);
    }
    draft.isScorable =
        typeId != 4 &&
        (draft.points != null ||
            key.isNotEmpty ||
            draft.options.any((o) => o.isCorrect));
    return draft;
  }

  /// Terapkan sebagian field pada draf soal yang sudah ada (update_question).
  void _updateDraft(QuestionDraft q, Map<String, dynamic> j) {
    q.typeId = j.containsKey('typeId') || j.containsKey('tipe')
        ? _typeIdFrom(j['typeId'] ?? j['tipe'])
        : q.typeId;
    if (!q.hasOptions) {
      // Tipe baru tanpa opsi (essay/tanggal/benar-salah) → opsi dibuang.
      for (final o in q.options) {
        o.text.dispose();
      }
      q.options.clear();
    }
    final key = (j['correctAnswer'] ?? j['kunci'])?.toString().trim();
    final text = (j['text'] ?? j['question'])?.toString();
    if (text != null) q.question.document = Document()..insert(0, text);
    if (key != null) q.correctAnswer.text = key;
    if (j['isRequired'] is bool) q.isRequired = j['isRequired'] as bool;
    if (j.containsKey('points')) {
      q.points = j['points'] is num ? (j['points'] as num).toInt() : null;
    }
    final options = j['options'] ?? j['opsi'];
    if (options is List && q.hasOptions) {
      _fillOptions(q, options, key ?? q.correctAnswer.text.trim());
    } else if (key != null && q.options.isNotEmpty) {
      _markCorrect(q, key);
    }
    if (q.typeId == 4) q.isScorable = false;
  }

  /// Terapkan semua aksi dari AFA; return ringkasan perubahan.
  List<String> _applyActions(List<dynamic> rawActions) {
    final applied = <String>[];
    final s = widget.settings?.call();
    final questions = widget.questions?.call();
    for (final raw in rawActions) {
      if (raw is! Map) continue;
      final action = Map<String, dynamic>.from(raw);
      switch ((action['type'] ?? '').toString()) {
        case 'set_title':
          if (s == null) break;
          final value = (action['value'] ?? '').toString().trim();
          if (value.isEmpty) break;
          s.titleController.text = value;
          applied.add('Judul form diubah');
          break;
        case 'set_description':
          if (s == null) break;
          s.descController.document = Document()
            ..insert(0, (action['value'] ?? '').toString());
          applied.add('Deskripsi form diubah');
          break;
        case 'add_question':
          if (questions == null) break;
          final spec = action['question'] ?? action['soal'];
          if (spec is! Map) break;
          questions.add(_draftFrom(Map<String, dynamic>.from(spec)));
          applied.add('Soal #${questions.length} ditambahkan');
          break;
        case 'update_question':
          if (questions == null) break;
          final i = action['index'] is num
              ? (action['index'] as num).toInt()
              : -1;
          if (i < 0 || i >= questions.length) break;
          _updateDraft(questions[i], action);
          applied.add('Soal #${i + 1} diperbarui');
          break;
        case 'delete_question':
          if (questions == null) break;
          final i = action['index'] is num
              ? (action['index'] as num).toInt()
              : -1;
          if (i < 0 || i >= questions.length) break;
          questions.removeAt(i).dispose();
          applied.add('Soal #${i + 1} dihapus');
          break;
        case 'clear_questions':
          if (questions == null || questions.isEmpty) break;
          for (final q in questions) {
            q.dispose();
          }
          questions.clear();
          applied.add('Semua soal dihapus');
          break;
      }
    }
    return applied;
  }

  Future<void> _pickFiles() async {
    if (_busy || _voice.isTranscribing) return;
    final picked = await pickAiAttachments(
      context,
      existingCount: _pendingAttachments.length,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() => _pendingAttachments = [..._pendingAttachments, ...picked]);
  }

  Future<void> _toggleVoice() async {
    await _voice.toggle(
      onText: (text) {
        final cur = _input.text;
        final insert = (cur.isEmpty || cur.endsWith(' ')) ? text : ' $text';
        _input.text = '$cur$insert';
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
        if (mounted) setState(() {});
      },
      onMessage: (message, {isError = false}) {
        if (mounted) showAuthToast(context, message, isError: isError);
      },
      onNeedApiKey: () {
        if (!mounted) return;
        showAiApiKeyDialog(context, onKeyChanged: () => setState(() {}));
      },
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    // Ukur tinggi pill prompt tiap build pasca-frame (bisa membesar saat
    // multiline / ada lampiran) — padding list & gradient mengikuti.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final h = _inputBarKey.currentContext?.size?.height;
      if (h != null && mounted && (h - _inputBarHeight).abs() > 0.5) {
        setState(() => _inputBarHeight = h);
      }
    });
    // Struktur Stack ala AiChatScreen: chat full-bleed digulir DI BELAKANG
    // baris atas & pill prompt (dengan gradient fade), lalu drawer riwayat
    // menutupi semuanya saat dibuka.
    return Container(
      color: bg,
      child: Stack(
        children: [
          Positioned.fill(
            child: _messages.isEmpty ? _emptyState(cs) : _chatList(cs),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _topBar(cs, bg)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bg.withValues(alpha: 0),
                      bg.withValues(alpha: 0.12),
                      bg.withValues(alpha: 0.32),
                      bg.withValues(alpha: 0.62),
                      bg.withValues(alpha: 0.92),
                      bg,
                    ],
                    stops: const [0.0, 0.25, 0.45, 0.65, 0.82, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _inputPill(cs),
            ),
          ),
          // Drawer selalu ter-mount agar animasi buka & tutup keduanya jalan;
          // saat tertutup tergeser keluar panel dan di-clip oleh Stack.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_drawerOpen,
              child: AnimatedSlide(
                offset: _drawerOpen ? Offset.zero : const Offset(1, 0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: _drawer(cs),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDrawer() {
    // Tutup keyboard dulu — pola _dismissKeyboard di AiChatScreen — agar
    // fokus tidak "kembali" sendiri ke field saat drawer ditutup.
    if (_focusNode.hasFocus) _focusNode.unfocus();
    setState(() => _drawerOpen = true);
  }

  /// Baris atas melayang (gradient scaffold → transparan): tombol tutup di
  /// kiri, satu tombol menu di kanan untuk membuka sidebar riwayat & setting.
  Widget _topBar(ColorScheme cs, Color bg) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            bg,
            bg,
            bg.withValues(alpha: 0.92),
            bg.withValues(alpha: 0.55),
            bg.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.35, 0.60, 0.80, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
      child: Row(
        children: [
          if (widget.onClose != null)
            IconButton(
              onPressed: widget.onClose,
              tooltip: 'Tutup AI Form Agent',
              icon: Icon(Icons.close, size: 22, color: cs.onSurface),
            ),
          const Spacer(),
          IconButton(
            onPressed: _openDrawer,
            tooltip: 'Riwayat & pengaturan',
            icon: Icon(Icons.menu_rounded, size: 22, color: cs.onSurface),
          ),
        ],
      ),
    );
  }

  /// Daftar pesan: lebar bubble dihitung dari lebar PANEL (LayoutBuilder),
  /// bukan lebar jendela seperti ChatBubble — panel sidebar hanya 380px di
  /// dalam jendela yang jauh lebih lebar.
  Widget _chatList(ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, cons) {
        final bubbleMaxW = cons.maxWidth * 0.82;
        return ListView.separated(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            12,
            _topBarHeight + 12,
            12,
            _inputBarHeight + 16,
          ),
          itemCount: _messages.length + (_busy ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i >= _messages.length) return _busyBubble(cs);
            return _bubble(cs, _messages[i], bubbleMaxW);
          },
        );
      },
    );
  }

  /// Empty state pola `ChatEmptyState`: ikon box (padding 20, radius 20,
  /// softShadow), judul kFontBold 16, subjudul 13, ActionChip 13 radius 20.
  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          _topBarHeight + 28,
          20,
          _inputBarHeight + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: softShadow(),
              ),
              child: AiChatIcon(size: 32, color: cs.primary, filled: true),
            ),
            const SizedBox(height: 16),
            Text(
              'AFA — AI Form Agent',
              style: TextStyle(
                fontFamily: kFontBold,
                fontSize: 16,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Minta AFA menyusun atau mengubah draf form & soal. Perubahan '
              'langsung masuk ke draf — tersimpan saat kamu menekan Simpan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final chip in _suggestions())
                  ActionChip(
                    label: Text(chip, style: const TextStyle(fontSize: 13)),
                    onPressed: () {
                      _input.text = chip;
                      _send();
                    },
                    backgroundColor: cs.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Saran cepat disesuaikan dengan kemampuan layar ini.
  List<String> _suggestions() {
    final hasSettings = widget.settings?.call() != null;
    final hasQuestions = widget.questions != null;
    return [
      if (hasQuestions) 'Buatkan 5 soal pilihan ganda',
      if (hasQuestions) 'Ubah semua soal jadi wajib dijawab',
      if (hasSettings) 'Buatkan deskripsi form yang menarik',
      if (!hasQuestions && !hasSettings) 'Apa yang bisa kamu bantu?',
    ];
  }

  /// Indikator menunggu: bubble AI (radius 24) berisi spinner + teks —
  /// pola bubble "AI mengetik..." di `ChatBubble`.
  Widget _busyBubble(ColorScheme cs) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: softShadow(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'AFA sedang menyusun draf...',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    ),
  );

  /// Bubble persis `ChatBubble`: radius 24, padding (16,12), teks 14.
  /// Lebar maksimum dihitung dari LayoutBuilder panel — BUKAN lebar jendela
  /// seperti ChatBubble (sidebar 380px di jendela 1400px akan salah ukur).
  Widget _bubble(ColorScheme cs, _AgentMsg m, double bubbleMaxW) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Bubble user tema-sadar — alasan sama seperti `ChatBubble`: skema gelap
    // memakai onPrimary gelap, sehingga teks tak terbaca di bubble terang.
    final userBubbleColor = isDark
        ? const Color(0xFF20443E)
        : const Color(0xFFB9EBDF);
    final userTextColor = isDark ? Colors.white : Colors.black87;
    // Error dibedakan dengan tint merah, adaptif gelap/terang seperti
    // `ChatBubble._ErrorBody` agar tetap kontras di kedua mode.
    final errorTint = Color.alphaBlend(
      Colors.red.withValues(alpha: 0.10),
      cs.surface,
    );
    final red = isDark ? Colors.red.shade300 : Colors.red.shade800;
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: bubbleMaxW),
        decoration: BoxDecoration(
          color: m.isUser
              ? userBubbleColor
              : (m.isError ? errorTint : cs.surface),
          // Semua sisi radius sama & lebih melengkung, persis `ChatBubble`.
          borderRadius: BorderRadius.circular(24),
          boxShadow: softShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.isUser && m.attachments.isNotEmpty) ...[
              BubbleAttachments(attachments: m.attachments, isUser: true),
              if (m.text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (m.isUser)
              SelectableText(
                m.text.isEmpty
                    ? (m.attachments.isNotEmpty ? '(lampiran)' : '...')
                    : m.text,
                style: TextStyle(
                  fontSize: 14,
                  color: userTextColor,
                  height: 1.35,
                ),
              )
            else if (m.isError)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 18, color: red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.text,
                      style: TextStyle(fontSize: 14, color: red, height: 1.35),
                    ),
                  ),
                ],
              )
            else
              GptMarkdown(
                m.text.isEmpty ? 'Respons kosong. Coba kirim ulang.' : m.text,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface,
                  height: 1.35,
                ),
              ),
            if (m.applied.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final item in m.applied)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(fontSize: 11, color: cs.primary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Drawer riwayat & pengaturan — meluncur dari kanan MENUTUPI seluruh
  /// panel (opaque, tanpa scrim); pola `AiChatDrawer` versi compact.
  /// Pengaturan memakai dialog API key (bukan pindah layar) agar alur
  /// edit form tidak terganggu.
  Widget _drawer(ColorScheme cs) {
    return Material(
      color: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: ikon + nama + model aktif + tombol tutup.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  AiChatIcon(color: cs.primary, size: 26, filled: true),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AFA',
                        style: TextStyle(
                          fontFamily: kFontBold,
                          fontSize: 16,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        GeminiService.selectedModelDisplay,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 22, color: cs.onSurface),
                    tooltip: 'Tutup',
                    onPressed: () => setState(() => _drawerOpen = false),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: _newSession,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Chat baru'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(indent: 16, endIndent: 16, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Riwayat',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _sessions.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada riwayat',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemCount: _sessions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (ctx, i) {
                        final s = _sessions[i];
                        final selected = s.id == _currentSessionId;
                        return Material(
                          color: selected
                              ? kPrimary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(kRadiusMd),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(kRadiusMd),
                            onTap: () => _switchSession(s.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.chat_bubble
                                        : Icons.chat_bubble_outline,
                                    size: 16,
                                    color: selected
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: selected
                                            ? cs.primary
                                            : cs.onSurface,
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () =>
                                        _confirmDeleteSession(s.id, s.title),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            // Bottom ala M3: Pengaturan + Hapus semua riwayat.
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.settings_outlined,
                      size: 24,
                      color: cs.onSurface,
                    ),
                    title: const Text(
                      'Pengaturan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                    onTap: () {
                      setState(() => _drawerOpen = false);
                      showAiApiKeyDialog(
                        context,
                        onKeyChanged: () => setState(() {}),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      size: 24,
                      color: kDangerColor,
                    ),
                    title: const Text(
                      'Hapus semua riwayat',
                      style: TextStyle(fontSize: 14),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                    onTap: _sessions.isEmpty ? null : _clearAllSessions,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pill prompt bersih: tanpa indikator konteks, tanpa label tambahan,
  /// kontrol kirim muncul hanya saat ada teks/lampiran.
  Widget _inputPill(ColorScheme cs) {
    final canSend =
        _input.text.trim().isNotEmpty || _pendingAttachments.isNotEmpty;
    final enabled = !_busy && !_voice.isTranscribing;
    return Container(
      key: _inputBarKey,
      padding: EdgeInsets.fromLTRB(
        8,
        _pendingAttachments.isNotEmpty ? 12 : 6,
        8,
        6,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: softShadow(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_pendingAttachments.isNotEmpty) ...[
            AiAttachmentPreview(
              attachments: _pendingAttachments,
              onRemove: (id) => setState(
                () => _pendingAttachments.removeWhere((a) => a.id == id),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: TextField(
              controller: _input,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              enabled: enabled,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) {
                if (canSend && enabled) _send();
              },
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration.collapsed(
                hintText: 'Tulis perintah untuk draf...',
              ),
              style: TextStyle(fontSize: 15, color: cs.onSurface, height: 1.35),
              cursorColor: cs.primary,
              mouseCursor: SystemMouseCursors.text,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed: enabled ? _pickFiles : null,
                tooltip: 'Lampirkan file',
                icon: Icon(Icons.add, size: 24, color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              AiModelPicker(
                dense: true,
                onChanged: () {
                  _focusNode.unfocus();
                  setState(() {});
                },
              ),
              const SizedBox(width: 4),
              if (canSend)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _micButton(cs, enabled),
                    const SizedBox(width: 4),
                    _sendButton(cs, canSend, enabled),
                  ],
                )
              else
                _micButton(cs, enabled),
            ],
          ),
        ],
      ),
    );
  }

  Widget _micButton(ColorScheme cs, bool enabled) {
    if (_voice.isTranscribing) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      onPressed: enabled ? _toggleVoice : null,
      tooltip: _voice.isRecording ? 'Berhenti merekam' : 'Rekam suara',
      icon: Icon(
        _voice.isRecording ? Icons.stop_circle : Icons.mic_none_outlined,
        size: 22,
        color: _voice.isRecording ? cs.error : cs.onSurfaceVariant,
      ),
    );
  }

  /// Tombol kirim: hanya muncul saat prompt siap dikirim. Ketika kosong,
  /// mic mengambil posisi paling kanan agar tampil seperti contoh referensi.
  Widget _sendButton(ColorScheme cs, bool canSend, bool enabled) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (!canSend) return const SizedBox(width: 40, height: 40);
    return Material(
      color: cs.primary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? _send : null,
        customBorder: const CircleBorder(),
        hoverColor: cs.onPrimary.withValues(alpha: 0.25),
        child: Tooltip(
          message: 'Kirim',
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.arrow_upward, size: 20, color: cs.onPrimary),
          ),
        ),
      ),
    );
  }
}
