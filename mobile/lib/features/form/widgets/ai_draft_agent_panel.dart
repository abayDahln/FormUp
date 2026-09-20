import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/gemini_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/loading_indicator.dart';
import 'package:form_up/features/form/controllers/form_maker_controller.dart';

/// Satu pesan di panel agent draf.
class _AgentMessage {
  final bool isUser;
  final String text;

  /// Ringkasan perubahan yang sudah diterapkan (pesan agent saja).
  final List<String> applied;
  final bool isError;

  const _AgentMessage({
    required this.isUser,
    required this.text,
    this.applied = const [],
    this.isError = false,
  });
}

/// Panel agent AI draf (sidebar kanan builder): chat yang LANGSUNG mengubah
/// draf lokal — pengaturan form + daftar soal — tanpa dialog persetujuan,
/// karena draf tetap milik user dan server hanya tersentuh saat user menekan
/// Simpan. Berbeda dari AI Chat screen (aksi ke server via PendingActionBar).
class AiDraftAgentPanel extends StatefulWidget {
  /// Akses controller pengaturan (title/desc/settings) draf; null bila
  /// kartu pengaturan belum ter-mount.
  final FormMakerController? Function()? settings;

  /// Daftar draf soal aktif (referensi langsung — dimutasi di tempat).
  final List<QuestionDraft> Function() questions;

  /// Memberi tahu screen agar rebuild setelah draf diubah.
  final void Function() onChanged;

  const AiDraftAgentPanel({
    super.key,
    required this.settings,
    required this.questions,
    required this.onChanged,
  });

  @override
  State<AiDraftAgentPanel> createState() => _AiDraftAgentPanelState();
}

class _AiDraftAgentPanelState extends State<AiDraftAgentPanel> {
  final List<_AgentMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

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

  /// Instruksi sistem + kontrak JSON: agent mengembalikan daftar aksi
  /// yang langsung diterapkan ke draf lokal.
  String _preamble() => '''
Kamu adalah agen penyusun form di aplikasi FormUp. Kamu bekerja pada DRAF
lokal (belum tersimpan) milik user: pengaturan form + daftar soal.
Balas HANYA satu objek JSON valid (tanpa markdown/penjelasan di luar JSON):

{"reply":"penjelasan singkat dalam Bahasa Indonesia","actions":[...]}

Aksi yang tersedia:
- {"type":"set_title","value":"..."}
- {"type":"set_description","value":"..."}
- {"type":"add_question","question":{"typeId":1|2|3|4|5,"text":"...","options":["A","B"],"correctAnswer":"A","isRequired":true,"points":10}}
- {"type":"update_question","index":0,"text":"...","typeId":2,"options":["A","B"],"correctAnswer":"B","isRequired":false,"points":null}
- {"type":"delete_question","index":1}
- {"type":"clear_questions"}

Aturan:
- typeId: 1=Essay, 2=Pilihan Ganda (min 2 opsi, tepat 1 kunci), 3=Checkbox
  (boleh >1 kunci, correctAnswer "A,C"), 4=Tanggal & Waktu (tanpa skor),
  5=Benar/Salah (correctAnswer "Benar" atau "Salah").
- index mengacu ke nomor soal pada DRAF SAAT INI (0-based, sesuai urutan).
- Pertahankan soal yang tidak diminta diubah — kirim aksi hanya untuk yang
  berubah, ditambah add_question untuk soal baru.
- Jika permintaan tidak butuh perubahan, kirim actions: [].
''';

  /// Snapshot draf lokal (pengaturan + soal) sebagai konteks untuk model.
  String _draftSnapshot() {
    final s = widget.settings?.call();
    final questions = widget.questions();
    final data = <String, dynamic>{
      'judul': s?.titleController.text.trim() ?? '',
      'deskripsi': s?.descController.document.toPlainText().trim() ?? '',
      'jumlah_soal': questions.length,
      'soal': [
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
      ],
    };
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

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    if (!GeminiService.hasKey) {
      setState(() {
        _messages.add(const _AgentMessage(
          isUser: false,
          text: 'API key Gemini belum diatur. Buka AI Chat > API Key.',
          isError: true,
        ));
      });
      _scrollToEnd();
      return;
    }

    _input.clear();
    setState(() {
      _messages.add(_AgentMessage(isUser: true, text: text));
      _busy = true;
    });
    _scrollToEnd();

    try {
      final history = <Map<String, String>>[
        for (final m in _messages)
          {'role': m.isUser ? 'user' : 'model', 'text': m.text},
      ];
      // Pesan user terakhir membawa instruksi + snapshot draf terkini.
      history.last['text'] =
          '${_preamble()}\n\nDRAF SAAT INI:\n${_draftSnapshot()}\n\nPERMINTAAN USER:\n$text';

      final raw = await GeminiService.generateOnce(history);
      final parsed = _extractJson(raw);
      if (!mounted) return;

      if (parsed == null) {
        setState(() {
          _busy = false;
          _messages.add(const _AgentMessage(
            isUser: false,
            text: 'Balasan agent tidak dapat dibaca. Coba lagi.',
            isError: true,
          ));
        });
        _scrollToEnd();
        return;
      }

      final applied =
          _applyActions((parsed['actions'] as List<dynamic>? ?? []));
      final reply = (parsed['reply'] as String?)?.trim();
      setState(() {
        _busy = false;
        _messages.add(_AgentMessage(
          isUser: false,
          text: reply == null || reply.isEmpty
              ? (applied.isEmpty
                  ? 'Tidak ada perubahan pada draf.'
                  : 'Draf diperbarui.')
              : reply,
          applied: applied,
        ));
      });
      if (applied.isNotEmpty) widget.onChanged();
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messages.add(_AgentMessage(
          isUser: false,
          text: GeminiService.friendlyMessage(e),
          isError: true,
        ));
      });
      _scrollToEnd();
    }
  }

  // --- Penerapan aksi ke draf lokal (tanpa persetujuan) ---

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
    draft.isScorable = typeId != 4 &&
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

  /// Terapkan semua aksi dari agent; return ringkasan perubahan.
  List<String> _applyActions(List<dynamic> rawActions) {
    final applied = <String>[];
    final s = widget.settings?.call();
    final questions = widget.questions();
    for (final raw in rawActions) {
      if (raw is! Map) continue;
      final action = Map<String, dynamic>.from(raw);
      switch ((action['type'] ?? '').toString()) {
        case 'set_title':
          final value = (action['value'] ?? '').toString().trim();
          if (value.isEmpty || s == null) break;
          s.titleController.text = value;
          applied.add('Judul form diubah');
          break;
        case 'set_description':
          if (s == null) break;
          s.descController.document =
              Document()..insert(0, (action['value'] ?? '').toString());
          applied.add('Deskripsi form diubah');
          break;
        case 'add_question':
          final spec = action['question'] ?? action['soal'];
          if (spec is! Map) break;
          questions.add(_draftFrom(Map<String, dynamic>.from(spec)));
          applied.add('Soal #${questions.length} ditambahkan');
          break;
        case 'update_question':
          final i = action['index'] is num
              ? (action['index'] as num).toInt()
              : -1;
          if (i < 0 || i >= questions.length) break;
          _updateDraft(questions[i], action);
          applied.add('Soal #${i + 1} diperbarui');
          break;
        case 'delete_question':
          final i = action['index'] is num
              ? (action['index'] as num).toInt()
              : -1;
          if (i < 0 || i >= questions.length) break;
          questions.removeAt(i).dispose();
          applied.add('Soal #${i + 1} dihapus');
          break;
        case 'clear_questions':
          if (questions.isEmpty) break;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _emptyState(cs)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  itemCount: _messages.length + (_busy ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= _messages.length) return _busyBubble(cs);
                    return _bubble(cs, _messages[i]);
                  },
                ),
        ),
        Divider(height: 1, color: cs.outlineVariant),
        _inputBar(cs),
      ],
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 36, color: cs.primary),
            const SizedBox(height: 10),
            Text(
              'Agent Draf AI',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Minta AI menyusun atau mengubah draf form & soal. Perubahan '
              'langsung masuk ke draf — tersimpan hanya saat kamu menekan Simpan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            for (final chip in const [
              'Buatkan 5 soal pilihan ganda tentang ...',
              'Ubah semua soal jadi wajib dijawab',
              'Hapus soal nomor 3',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton(
                  onPressed: () {
                    _input.text = chip;
                    _send();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.primary,
                    side: BorderSide(color: cs.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: Text(chip, textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _busyBubble(ColorScheme cs) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: LoadingIndicator.inline(),
            ),
            const SizedBox(width: 8),
            Text(
              'Agent sedang menyusun draf...',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );

  Widget _bubble(ColorScheme cs, _AgentMessage m) {
    final bg = m.isError
        ? cs.errorContainer
        : (m.isUser ? cs.primaryContainer : cs.surfaceContainerHighest);
    final fg = m.isError
        ? cs.onErrorContainer
        : (m.isUser ? cs.onPrimaryContainer : cs.onSurface);
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.text,
              style: TextStyle(fontSize: 12.5, color: fg, height: 1.35),
            ),
            if (m.applied.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final item in m.applied)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 13, color: cs.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(fontSize: 11.5, color: cs.primary),
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

  Widget _inputBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              enabled: !_busy,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Tulis perintah untuk draf...',
                hintStyle:
                    TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
              ),
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _busy ? null : _send,
            tooltip: 'Kirim perintah',
            style: IconButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
            icon: const Icon(Icons.arrow_upward, size: 18),
          ),
        ],
      ),
    );
  }
}
