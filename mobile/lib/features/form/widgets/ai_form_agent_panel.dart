import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
///
/// Pesan asisten yang menerapkan perubahan draf menyimpan [undoSnapshot]
/// (salinan draf SEBELUM aksi) sehingga perubahan bisa diurungkan tanpa
/// redo. Snapshot hanya hidup di memori sesi aktif — setelah restart aplikasi
/// undo tidak tersedia untuk riwayat lama (tombol disembunyikan).
class _AgentMsg {
  final bool isUser;
  String text;

  /// Ringkasan perubahan draf yang diterapkan pada pesan ini.
  final List<String> applied;
  final bool isError;
  List<AiAttachment> attachments;

  /// Snapshot draf sebelum aksi pesan ini diterapkan (null = tak bisa undo:
  /// tidak ada aksi, atau pesan dimuat dari riwayat tersimpan).
  _DraftSnapshot? undoSnapshot;

  /// True bila perubahan pesan ini sudah diurungkan.
  bool undone;

  _AgentMsg({
    required this.isUser,
    required this.text,
    this.applied = const [],
    this.isError = false,
    this.attachments = const [],
    this.undoSnapshot,
    this.undone = false,
  });
}

/// Salinan draf form (judul + deskripsi + daftar soal) pada satu titik waktu.
/// Dipakai undo: diambil SEBELUM aksi AFA diterapkan, dikembalikan saat undo.
/// Seluruh field nullable — null artinya "tidak tersedia / jangan sentuh"
/// (mis. layar tanpa kartu pengaturan, atau tab Soal belum dibangun).
class _DraftSnapshot {
  final String? title;
  final String? descPlain;
  final List<QuestionDraft>? questions;

  const _DraftSnapshot({this.title, this.descPlain, this.questions});
}

/// Hasil satu aksi AFA: ringkasan untuk bubble + indeks soal yang tersentuh
/// (untuk highlight kartu; kosong bila tak ada kartu terkait).
class _AppliedOne {
  final String summary;
  final List<int> touched;

  const _AppliedOne(this.summary, [this.touched = const []]);
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
  /// null bila layar ini tidak punya daftar soal ATAU daftar belum siap
  /// (mis. tab Soal belum dibangun — kemampuan soal lalu dianggap mati agar
  /// AFA tidak mengklaim bisa mengubah soal lalu hasilnya hilang).
  final List<QuestionDraft>? Function()? questions;

  /// Memberi tahu screen agar rebuild setelah draf diubah.
  final void Function() onChanged;

  /// Dipanggil SETIAP satu aksi soal diterapkan (mode staggered): berisi
  /// indeks soal yang baru ditambah/diubah pada langkah itu. Layar memakai
  /// ini untuk highlight + auto-scroll ke kartu soal tersebut. Kosong untuk
  /// aksi pengaturan (judul/deskripsi) dan aksi hapus.
  final void Function(List<int> touched)? onQuestionsTouched;

  /// Menutup panel (null = tidak ada tombol tutup, mis. dipakai sebagai
  /// kartu penuh di sidebar).
  final VoidCallback? onClose;

  const AiFormAgentPanel({
    super.key,
    required this.formId,
    this.settings,
    this.questions,
    required this.onChanged,
    this.onQuestionsTouched,
    this.onClose,
  });

  @override
  State<AiFormAgentPanel> createState() => AiFormAgentPanelState();
}

class AiFormAgentPanelState extends State<AiFormAgentPanel> {
  final List<_AgentMsg> _messages = [];
  final TextEditingController _input = TextEditingController();

  /// Fokus field prompt. Di platform keyboard fisik (Windows/macOS/Linux/web)
  /// Enter = kirim, Shift+Enter = baris baru (lihat [_hardwareEnterToSend]).
  /// Mobile tidak disentuh agar perilaku soft keyboard tetap apa adanya.
  late final FocusNode _focusNode = FocusNode(
    onKeyEvent: (node, event) {
      if (!_hardwareEnterToSend) return KeyEventResult.ignored;
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey != LogicalKeyboardKey.enter) {
        return KeyEventResult.ignored;
      }
      // Shift+Enter (atau Ctrl/Alt/Meta+Enter) = baris baru, bukan kirim.
      final hw = HardwareKeyboard.instance;
      if (hw.isShiftPressed || hw.isControlPressed || hw.isAltPressed) {
        return KeyEventResult.ignored;
      }
      if (hw.isMetaPressed) return KeyEventResult.ignored;
      // Kosong = biarkan (newline tak merusak); sibuk/merekam/edit = telan
      // agar tak menambah baris ke antrean kirim.
      if (_input.text.trim().isEmpty && _pendingAttachments.isEmpty) {
        return KeyEventResult.ignored;
      }
      if (_busy || _voice.isTranscribing || _editingIndex != null) {
        return KeyEventResult.handled;
      }
      _send();
      return KeyEventResult.handled;
    },
  );
  final ScrollController _scroll = ScrollController();
  final AiVoiceRecorder _voice = AiVoiceRecorder();

  List<AiAttachment> _pendingAttachments = [];
  List<FormAgentSession> _sessions = [];
  String? _currentSessionId;
  bool _busy = false;

  /// Awal fase thinking terakhir — dipakai menahan TAMPILAN thinking minimal
  /// [_kMinThinking] agar animasi "AI sedang membuat" sempat terlihat
  /// walau API menjawab sangat cepat (delay cepat, bukan blokir lama).
  DateTime _busySince = DateTime.now();

  /// Durasi tampil minimal indikator thinking.
  static const _kMinThinking = Duration(milliseconds: 800);

  /// Indeks pesan user yang sedang diedit (null = tidak ada mode edit).
  /// Hanya pesan user TERAKHIR yang bisa diedit (aturan anti-rusak, lihat
  /// [_saveEdit]) sehingga satu variabel cukup.
  int? _editingIndex;
  final TextEditingController _editController = TextEditingController();

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
    _editController.dispose();
    _focusNode.dispose();
    _scroll.dispose();
    _voice.dispose();
    super.dispose();
  }

  /// True di platform keyboard fisik (desktop + web): Enter = kirim,
  /// Shift+Enter = baris baru. Android/iOS selalu false agar soft keyboard
  /// (aksi newline) tidak berubah perilakunya.
  bool get _hardwareEnterToSend {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
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
        _editingIndex = null;
        _drawerOpen = false;
      });
      return;
    }
    setState(() {
      _currentSessionId = _newId();
      _messages.clear();
      _pendingAttachments = [];
      _editingIndex = null;
      _drawerOpen = false;
    });
  }

  Future<void> _switchSession(String id) async {
    // Dilarang saat AI bekerja: balasan yang sedang berjalan akan tertempel
    // ke sesi yang salah bila sesi diganti di tengah jalan.
    if (_busy) {
      if (mounted) {
        showAuthToast(
          context,
          'Tunggu AFA selesai bekerja dulu',
          isError: true,
        );
      }
      return;
    }
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
      _editingIndex = null;
      _drawerOpen = false;
    });
    _scrollToEnd();
  }

  Future<void> _deleteSession(String id) async {
    if (_busy) return;
    await AiFormAgentHistoryService.delete(_historyFormId, id);
    final all = await AiFormAgentHistoryService.loadSessions(_historyFormId);
    if (!mounted) return;
    setState(() => _sessions = all);
    if (_currentSessionId != id) return;
    if (all.isEmpty) {
      setState(() {
        _messages.clear();
        _editingIndex = null;
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
      _editingIndex = null;
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
  /// Snapshot undo TIDAK dipersist (berat) → pesan lama tak bisa di-undo;
  /// flag [FormAgentMessage.undone] tetap ditampilkan sebagai "Dibatalkan".
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
      undone: m.undone,
    );
  }

  FormAgentMessage _toHistory(_AgentMsg m) => FormAgentMessage(
    isUser: m.isUser,
    text: m.text,
    applied: m.applied,
    isError: m.isError,
    undone: m.undone,
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
    // Mode edit / rekam suara aktif: selesaikan dulu agar tidak tumpang tindih.
    if (_editingIndex != null || _voice.isTranscribing) return;

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
      _busySince = DateTime.now();
    });
    // Bubble user + thinking langsung terlihat: scroll ke bawah SEKARANG
    // (posisi dihitung pasca-frame, sudah termasuk bubble thinking).
    _scrollToEnd();

    await _generateAndApply(attachments);
  }

  /// Inti pemanggilan AI: dipakai kirim baru ([_send]), retry ([_retry]),
  /// dan kirim ulang setelah edit ([_saveEdit]). Membangun konteks dari
  /// [_messages] terkini, menahan thinking minimal [_kMinThinking] (delay
  /// cepat agar animasi sempat terlihat), mengambil snapshot SEBELUM
  /// menerapkan aksi (bahan undo), lalu persist + auto-scroll.
  Future<void> _generateAndApply(List<AiAttachment> inlineAttachments) async {
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
        inlineAttachments: inlineAttachments.isEmpty ? null : inlineAttachments,
        // Kontrak AFA menggantikan prompt AI Chat umum — tanpa ini dua
        // skema JSON bertabrakan dan balasan sering tak terbaca.
        systemInstruction: _systemInstruction(),
      );
      // Delay cepat: animasi thinking dijamin tampil minimal 800ms.
      final elapsed = DateTime.now().difference(_busySince);
      if (elapsed < _kMinThinking) {
        await Future.delayed(_kMinThinking - elapsed);
      }
      if (!mounted) return;

      final parsed = _extractJson(raw);
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

      // Snapshot SEBELUM mutasi — dibuang bila ternyata tak ada aksi agar
      // memori tidak membengkak (salinan Quill document per soal).
      final snapshot = _captureSnapshot();
      // Staggered: soal muncul satu per satu (±300ms) dengan highlight +
      // auto-scroll per langkah, bukan sekaligus.
      final applied = await _applyActionsStaggered(
        parsed['actions'] as List<dynamic>? ?? [],
      );
      if (!mounted) return;
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
            undoSnapshot: applied.isEmpty ? null : snapshot,
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

  // --- Snapshot / undo / retry / edit / salin ---
  //
  // Aturan anti-rusak (validasi inti):
  // - Tombol aksi pesan disembunyikan selama [_busy] / transkripsi suara.
  // - Edit hanya untuk pesan user TERAKHIR; menyimpan edit memotong &
  //   mengurungkan semua balasan sesudahnya (urutan terbalik) lalu kirim
  //   ulang — riwayat tak pernah inkonsisten dengan draf.
  // - Retry hanya untuk pesan asisten TERAKHIR; aksi balasan lama diurungkan
  //   dulu memakai snapshotnya lalu pesan dihapus dan prompt dikirim ulang.
  // - Undo hanya bila tak ada balasan LEBIH BARU yang masih memegang
  //   perubahan aktif (belum di-undo) — mengurungkan aksi lama di tengah
  //   tumpukan akan merusak draf. Tanpa redo (sesuai permintaan).
  // - Batasan yang diterima: undo mengembalikan SELURUH draf ke snapshot
  //   (edit manual user setelah snapshot ikut kembali), dan draf yang sedang
  //   dibuka di layar editor soal TIDAK di-dispose saat undo (mencegah crash
  //   controller yang sedang dipakai — hanya bocor kecil, aman).

  /// Salinan draf saat ini (sebelum mutasi). Daftar soal disalin dalam
  /// ([QuestionDraft.copy]) agar restore tak berbagi objek dengan live list.
  _DraftSnapshot? _captureSnapshot() {
    final s = widget.settings?.call();
    final qs = widget.questions?.call();
    if (s == null && qs == null) return null;
    return _DraftSnapshot(
      title: s?.titleController.text,
      descPlain: s?.descController.document.toPlainText(),
      questions: qs == null ? null : [for (final q in qs) q.copy()],
    );
  }

  /// Kembalikan draf ke [snap]. Draf live yang diganti SENGAJA tidak
  /// di-dispose: salah satunya mungkin sedang dibuka di layar editor soal
  /// dan dispose akan meledakkan controller yang sedang dipakai.
  void _restoreSnapshot(_DraftSnapshot snap) {
    final s = widget.settings?.call();
    if (s != null && snap.title != null) {
      s.titleController.text = snap.title!;
      s.descController.document = Document()..insert(0, snap.descPlain ?? '');
    }
    final qs = widget.questions?.call();
    if (qs != null && snap.questions != null) {
      qs
        ..clear()
        ..addAll(snap.questions!);
    }
  }

  /// True bila [snap] masih bisa dikembalikan ke draf SEKARANG (sisi draf
  /// yang disentuh snapshot harus tersedia). Mencegah restore setengah jalan
  /// yang membuat draf divergen dari riwayat — mis. tab Soal ter-dispose.
  bool _canRestoreNow(_DraftSnapshot snap) {
    if (snap.title != null && widget.settings?.call() == null) return false;
    if (snap.questions != null && widget.questions?.call() == null) {
      return false;
    }
    return true;
  }

  void _toastDraftUnavailable() {
    if (mounted) {
      showAuthToast(
        context,
        'Draf tidak tersedia — buka tab Soal dulu lalu coba lagi',
        isError: true,
      );
    }
  }

  /// True = pesan asisten [index] boleh di-undo sekarang.
  bool _canUndo(int index) {
    if (index < 0 || index >= _messages.length) return false;
    final m = _messages[index];
    if (m.isUser || m.isError) return false;
    if (m.applied.isEmpty || m.undone || m.undoSnapshot == null) return false;
    // Tolak bila ada balasan lebih baru yang masih memegang perubahan aktif.
    for (var j = index + 1; j < _messages.length; j++) {
      final later = _messages[j];
      if (!later.isUser &&
          !later.isError &&
          later.applied.isNotEmpty &&
          !later.undone) {
        return false;
      }
    }
    return true;
  }

  /// Indeks pesan user terakhir (null bila belum ada).
  int? _lastUserIndex() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) return i;
    }
    return null;
  }

  /// Urungkan perubahan satu pesan asisten.
  Future<void> _undo(int index) async {
    if (_busy || _voice.isTranscribing) return;
    if (!_canUndo(index)) return;
    final msg = _messages[index];
    final snap = msg.undoSnapshot;
    if (snap == null) return;
    if (!_canRestoreNow(snap)) {
      _toastDraftUnavailable();
      return;
    }
    _restoreSnapshot(snap);
    setState(() => msg.undone = true);
    widget.onChanged();
    await _persistSession();
    _scrollToEnd();
    if (mounted) showAuthToast(context, 'Perubahan AFA dibatalkan');
  }

  /// Kirim ulang prompt pesan user [userIndex] (dipakai retry & edit).
  /// Prasyarat: tidak busy, API key ada. Mengatur [_busy] + scroll sendiri.
  Future<void> _resendUserMessage(_AgentMsg userMsg) async {
    if (!GeminiService.hasKey) {
      setState(() {
        _messages.add(
          _AgentMsg(
            isUser: false,
            text: 'API key Gemini belum diatur.',
            isError: true,
          ),
        );
      });
      _scrollToEnd();
      return;
    }
    setState(() {
      _busy = true;
      _busySince = DateTime.now();
    });
    _scrollToEnd();
    await _generateAndApply(userMsg.attachments);
  }

  /// Coba lagi balasan asisten TERAKHIR: urungkan aksinya, hapus balasan,
  /// lalu kirim ulang prompt user sebelumnya (beserta lampirannya).
  Future<void> _retry(int index) async {
    if (_busy || _voice.isTranscribing || _editingIndex != null) return;
    if (index < 0 ||
        index >= _messages.length ||
        index != _messages.length - 1) {
      return;
    }
    final msg = _messages[index];
    if (msg.isUser) return;
    final u = _lastUserIndex();
    // Balasan tanpa prompt pendahulu (tak mungkin normal) → tolak.
    if (u == null || u > index) return;
    final userMsg = _messages[u];
    if (!msg.isError &&
        msg.applied.isNotEmpty &&
        !msg.undone &&
        msg.undoSnapshot != null) {
      if (!_canRestoreNow(msg.undoSnapshot!)) {
        _toastDraftUnavailable();
        return;
      }
      _restoreSnapshot(msg.undoSnapshot!);
    }
    setState(() => _messages.removeAt(index));
    widget.onChanged();
    await _resendUserMessage(userMsg);
  }

  /// Masuk mode edit untuk pesan user TERAKHIR.
  void _beginEdit(int index) {
    if (_busy || _voice.isTranscribing) return;
    if (index != _lastUserIndex()) return;
    _editController.text = _messages[index].text;
    setState(() => _editingIndex = index);
  }

  void _cancelEdit() {
    setState(() => _editingIndex = null);
  }

  /// Simpan edit: urungkan semua aksi balasan sesudah pesan ini (terbalik),
  /// potong riwayat, perbarui teks, lalu kirim ulang (termasuk undo).
  Future<void> _saveEdit(int index) async {
    if (_busy || _voice.isTranscribing) return;
    if (index < 0 || index >= _messages.length) return;
    final msg = _messages[index];
    if (!msg.isUser || index != _lastUserIndex()) return;
    final newText = _editController.text.trim();
    if (newText.isEmpty) {
      if (mounted) {
        showAuthToast(context, 'Pesan tidak boleh kosong', isError: true);
      }
      return;
    }
    // Teks sama → keluar mode edit tanpa kirim ulang.
    if (newText == msg.text) {
      setState(() => _editingIndex = null);
      return;
    }
    for (var j = _messages.length - 1; j > index; j--) {
      final m = _messages[j];
      if (!m.isUser &&
          !m.isError &&
          m.applied.isNotEmpty &&
          !m.undone &&
          m.undoSnapshot != null) {
        // Draf divergen (sisi draf tak tersedia) → batalkan seluruh operasi
        // sebelum riwayat terpotong, agar tak ada state setengah jalan.
        if (!_canRestoreNow(m.undoSnapshot!)) {
          _toastDraftUnavailable();
          return;
        }
        _restoreSnapshot(m.undoSnapshot!);
      }
    }
    setState(() {
      msg.text = newText;
      _messages.removeRange(index + 1, _messages.length);
      _editingIndex = null;
    });
    widget.onChanged();
    await _resendUserMessage(msg);
  }

  /// Salin teks pesan ke papan klip.
  Future<void> _copyText(String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showAuthToast(context, 'Disalin ke papan klip');
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

    // Identitas form yang sedang dibuka — disuntik eksplisit agar AFA selalu
    // membaca & mengubah HANYA form ini (setara '@mention' permanen).
    final formTitle =
        (widget.settings?.call()?.titleController.text.trim() ?? '');
    final formIdLabel = widget.formId == null
        ? 'baru (belum disimpan, id=null)'
        : '#${widget.formId}';
    final formTitleLabel =
        formTitle.isEmpty ? '(belum ada judul)' : '"$formTitle"';

    return '''
Kamu adalah "AFA" (AI Form Agent) di aplikasi FormUp.

KONTEKS FORM SAAT INI: id=$formIdLabel, judul=$formTitleLabel.
Form ini otomatis menjadi konteks percakapan — setara '@mention' permanen:
user TIDAK memakai sintaks '@' dan kamu tidak perlu (dan tidak boleh)
meminta user menyebut form. Kamu TIDAK punya akses ke form lain dalam
bentuk apa pun: tidak bisa membaca, mengubah, mencari, atau menyebut form
lain (teks yang mengandung '@' diperlakukan sebagai teks biasa). Jika user
menyebut atau meminta form lain, tolak dengan sopan di "reply" dan kirim
"actions": []. Seluruh aksi hanya berlaku untuk DRAF SAAT INI di bawah.

Balas HANYA satu objek JSON valid (tanpa markdown/penjelasan di luar JSON):
{"reply":"penjelasan singkat dalam Bahasa Indonesia","actions":[...]}

${actions.isEmpty ? 'Tidak ada aksi yang tersedia saat ini.' : 'Aksi yang tersedia:\n${actions.join('\n')}'}
${capability.isEmpty ? 'Kamu tidak bisa mengubah draf apa pun saat ini — jawab pertanyaan user saja dengan "actions": [].' : 'Bagian draf yang BISA kamu ubah saat ini: ${capability.join(' dan ')}.'}
Jika user meminta perubahan pada bagian yang TIDAK tersedia, tolak dengan sopan di
"reply", kirim "actions": [], dan jelaskan singkat bahwa bagian itu diubah dari layar lain.

Aturan:
- Untuk MENGUBAH soal yang sudah ada, pakai "update_question" dengan "index"
  yang tepat — JANGAN hapus lalu tambah ulang kecuali user meminta eksplisit.
  Kirim hanya field yang berubah (field lain dipertahankan).
- Untuk judul & deskripsi form, pakai "set_title" / "set_description".
- typeId: 1=Essay, 2=Pilihan Ganda (min 2 opsi, tepat 1 kunci), 3=Checkbox
  (boleh >1 kunci, correctAnswer "A,C"), 4=Tanggal & Waktu (tanpa skor),
  5=Benar/Salah (correctAnswer "Benar" atau "Salah").
- Kontrak kunci jawaban (wajib):
  - Pilihan ganda: TEPAT 1 opsi benar — kirim "correctAnswer" = teks persis
    opsi benar, dan/atau "isCorrect": true pada tepat 1 opsi. Jangan keduanya
    berbeda, jangan 0, jangan 2+.
  - Soal tanpa skor: tanpa kunci (correctAnswer kosong, semua isCorrect false).
- index mengacu ke nomor soal pada DRAF SAAT INI (0-based, sesuai urutan).
- Pertahankan soal yang tidak diminta diubah — kirim aksi hanya untuk yang
  berubah, ditambah add_question untuk soal baru.
- Lampiran dari user (gambar/dokumen) bisa kamu baca — jadikan sumber isi soal
  bila user memintanya (mis. "buatkan soal dari gambar ini").
- Aturan jumlah soal (WAJIB dipatuhi — API key milik user sendiri, jadi layani sampai tuntas):
  - Patuhi jumlah yang diminta user, MAKSIMAL 50 soal per permintaan. Bila user meminta lebih dari 50, kerjakan 50 dulu lalu tawarkan sisanya.
  - 15 soal atau kurang: kerjakan SEMUA dalam SATU respons ini.
  - Lebih dari 15 soal: kirim chunk PERTAMA yang valid (10-15 aksi add_question), tulis di "reply" sisa jumlahnya + "balas 'lanjut' untuk sisanya".
  - Saat user balas 'lanjut' (atau setuju lanjut): kirim chunk BERIKUTNYA (10-15 add_question), JANGAN mengulang soal yang sudah dibuat. Ulangi sampai total mencapai jumlah yang diminta.
  - DILARANG meringkas permintaan besar menjadi sedikit soal (mis. diminta 30 hanya dibuat 5). DILARANG menolak dengan alasan limit — batasnya 50, bukan 5.
- Jika permintaan tidak butuh perubahan, kirim "actions": [].

DRAF SAAT INI:
${_draftSnapshot(s, questions)}''';
  }

  /// Snapshot draf lokal (hanya bagian yang tersedia di layar ini).
  /// Selalu diawali identitas form (id) agar AFA terikat ke form saat ini.
  String _draftSnapshot(
    FormMakerController? s,
    List<QuestionDraft>? questions,
  ) {
    final data = <String, dynamic>{};
    data['form_id'] = widget.formId;
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
    // Angka dalam bentuk string ("2") — sebelumnya jatuh ke default esai
    // sehingga opsi + kunci ikut terbuang.
    final asNum = int.tryParse(v?.toString().trim() ?? '');
    if (asNum != null && questionTypes.containsKey(asNum)) return asNum;
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
      // Hormati flag isCorrect bawaan AI bila tanpa kunci eksplisit —
      // sebelumnya flag ini dibuang sehingga kunci AI hilang.
      final flag = key.isEmpty && o is Map && o['isCorrect'] == true;
      q.options.add(OptionDraft(text: text.trim(), isCorrect: flag));
    }
    if (key.isNotEmpty && q.options.isNotEmpty) _markCorrect(q, key);
    _enforceSingleCorrect(q);
  }

  /// Pilihan ganda: tepat 1 kunci — pertahankan yang pertama, sisanya
  /// dimatikan. Mencegah kunci ganda lolos ke penyimpanan.
  void _enforceSingleCorrect(QuestionDraft q) {
    if (q.typeId != 2) return;
    var kept = false;
    for (final o in q.options) {
      if (!o.isCorrect) continue;
      if (!kept) {
        kept = true;
      } else {
        o.isCorrect = false;
      }
    }
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
      // Kunci eksplisit dari AI menang; bila tak ada, flag bawaan opsi
      // dipakai — lalu kunci lama dicoba lagi agar tidak hilang sia-sia
      // (mis. AI hanya menyusun ulang/redaksi opsi).
      final explicitKey = (j['correctAnswer'] ?? j['kunci'])?.toString().trim() ?? '';
      _fillOptions(q, options, explicitKey);
      if (explicitKey.isEmpty && !q.options.any((o) => o.isCorrect)) {
        _markCorrect(q, q.correctAnswer.text.trim());
        _enforceSingleCorrect(q);
      }
    } else if (key != null && q.options.isNotEmpty) {
      _markCorrect(q, key);
      _enforceSingleCorrect(q);
    }
    if (q.typeId == 4) q.isScorable = false;
  }

  /// Terapkan semua aksi dari AFA satu per satu (STAGGERED, bukan sekaligus):
  /// setiap aksi diterapkan → [onChanged] + [onQuestionsTouched] (highlight &
  /// auto-scroll kartu) → jeda ±300ms (skala dengan kerumitan soal) → aksi
  /// berikutnya. Return ringkasan perubahan.
  ///
  /// Panel boleh ditutup di tengah jeda: sisa aksi tetap diselesaikan TANPA
  /// jeda/notify (draf milik parent yang masih hidup), snapshot undo tetap
  /// mencakup seluruh batch karena diambil sebelum loop (lihat pemanggil).
  Future<List<String>> _applyActionsStaggered(
    List<dynamic> rawActions,
  ) async {
    final applied = <String>[];
    for (final raw in rawActions) {
      if (raw is! Map) continue;
      final action = Map<String, dynamic>.from(raw);
      // Jeda stagger membuka jendela race: user bisa keluar layar (draf
      // ter-dispose) di tengah batch. Kegagalan satu aksi menghentikan sisa
      // batch — bubble hanya melaporkan yang benar-benar teraplikasi.
      _AppliedOne? res;
      try {
        res = _applyOne(action);
      } catch (_) {
        break;
      }
      if (res == null) continue;
      applied.add(res.summary);
      widget.onChanged();
      if (res.touched.isNotEmpty) {
        widget.onQuestionsTouched?.call(res.touched);
      }
      if (!mounted) continue;
      await Future.delayed(_staggerDelayFor(action));
    }
    return applied;
  }

  /// Jeda antar aksi: ±300ms, membesar mengikuti kerumitan soal (jumlah opsi
  /// pada tambah/ubah) agar soal kompleks terasa "dikerjakan" lebih lama.
  /// Hapus/basis 200ms. Dibatasi 550ms agar batch besar tak berlarut.
  Duration _staggerDelayFor(Map<String, dynamic> action) {
    switch ((action['type'] ?? '').toString()) {
      case 'add_question':
      case 'update_question':
        final spec = action['question'] ?? action['soal'];
        var options = 0;
        if (spec is Map) {
          final raw = spec['options'] ?? spec['opsi'];
          if (raw is List) options = raw.length;
        }
        return Duration(milliseconds: (250 + options * 50).clamp(250, 550));
      default:
        return const Duration(milliseconds: 200);
    }
  }

  /// Hasil satu aksi: ringkasan + indeks soal yang tersentuh (untuk highlight).
  /// Null = aksi dilewati (kemampuan mati / indeks tak valid / value kosong).
  _AppliedOne? _applyOne(Map<String, dynamic> action) {
    final s = widget.settings?.call();
    final questions = widget.questions?.call();
    switch ((action['type'] ?? '').toString()) {
      case 'set_title':
        if (s == null) return null;
        final value = (action['value'] ?? '').toString().trim();
        if (value.isEmpty) return null;
        s.titleController.text = value;
        return const _AppliedOne('Judul form diubah');
      case 'set_description':
        if (s == null) return null;
        s.descController.document = Document()
          ..insert(0, (action['value'] ?? '').toString());
        return const _AppliedOne('Deskripsi form diubah');
      case 'add_question':
        if (questions == null) return null;
        final spec = action['question'] ?? action['soal'];
        if (spec is! Map) return null;
        questions.add(_draftFrom(Map<String, dynamic>.from(spec)));
        return _AppliedOne(
          'Soal #${questions.length} ditambahkan',
          [questions.length - 1],
        );
      case 'update_question':
        if (questions == null) return null;
        final i = action['index'] is num
            ? (action['index'] as num).toInt()
            : -1;
        if (i < 0 || i >= questions.length) return null;
        _updateDraft(questions[i], action);
        return _AppliedOne('Soal #${i + 1} diperbarui', [i]);
      case 'delete_question':
        if (questions == null) return null;
        final i = action['index'] is num
            ? (action['index'] as num).toInt()
            : -1;
        if (i < 0 || i >= questions.length) return null;
        questions.removeAt(i).dispose();
        // Soal sudah tak ada → tak ada kartu untuk di-highlight.
        return _AppliedOne('Soal #${i + 1} dihapus');
      case 'clear_questions':
        if (questions == null || questions.isEmpty) return null;
        for (final q in questions) {
          q.dispose();
        }
        questions.clear();
        return const _AppliedOne('Semua soal dihapus');
    }
    return null;
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
  /// kiri, chip konteks form saat ini di tengah, satu tombol menu di kanan
  /// untuk membuka sidebar riwayat & setting.
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
          Expanded(child: _contextChip(cs)),
          IconButton(
            onPressed: _openDrawer,
            tooltip: 'Riwayat & pengaturan',
            icon: Icon(Icons.menu_rounded, size: 22, color: cs.onSurface),
          ),
        ],
      ),
    );
  }

  /// Chip konteks form saat ini — menegaskan AFA otomatis terikat ke form
  /// ini (setara '@mention' permanen, tanpa sintaks '@') dan tidak bisa
  /// membaca/mengubah form lain.
  Widget _contextChip(ColorScheme cs) {
    final title = widget.settings?.call()?.titleController.text.trim() ?? '';
    final id = widget.formId;
    final label = id == null
        ? (title.isEmpty ? 'Draf baru' : title)
        : (title.isEmpty ? 'Form #$id' : '$title (#$id)');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 14, color: cs.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Daftar pesan: lebar bubble dihitung dari lebar PANEL (LayoutBuilder),
  /// bukan lebar jendela seperti ChatBubble — panel sidebar hanya 380px di
  /// dalam jendela yang jauh lebih lebar.
  Widget _chatList(ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, cons) {
        // Bubble dibatasi 92% lebar panel agar terlihat lebih lebar dan
        // proporsional dengan card form setting & soal di sebelahnya.
        final bubbleMaxW = cons.maxWidth * 0.92;
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
            if (i >= _messages.length) return _busyBubble();
            final m = _messages[i];
            // Tombol aksi (salin/edit/retry/undo) di BAWAH bubble — bukan di
            // dalam — agar seleksi teks di dalam bubble tak terganggu.
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: m.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _bubble(cs, i, m, bubbleMaxW),
                _bubbleActions(cs, i, m),
              ],
            );
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

  /// Indikator thinking: bubble AI berisi tiga titik berdenyut + label yang
  /// berganti ("memahami perintah" → "menyusun draf"). Widget mandiri agar
  /// animasi jalan tanpa rebuild panel; tampil minimal [_kMinThinking].
  Widget _busyBubble() => const Align(
    alignment: Alignment.centerLeft,
    child: _ThinkingBubble(),
  );

  /// Bubble persis `ChatBubble`: radius 24, padding (16,12), teks 14.
  /// Lebar maksimum dihitung dari LayoutBuilder panel — BUKAN lebar jendela
  /// seperti ChatBubble (sidebar 380px di jendela 1400px akan salah ukur).
  ///
  /// Isi bubble saja (tanpa tombol aksi — aksi dirender DI BAWAH bubble oleh
  /// [_bubbleActions] agar seleksi teks di dalam bubble tak terganggu).
  /// Baris aksi disembunyikan selama [_busy] atau transkripsi suara. Edit
  /// khusus pesan user terakhir, retry khusus balasan terakhir, undo
  /// mengikuti [_canUndo].
  Widget _bubble(ColorScheme cs, int index, _AgentMsg m, double bubbleMaxW) {
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
            if (m.isUser && _editingIndex == index)
              _editField(cs, index, userTextColor)
            else if (m.isUser)
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
                        m.undone
                            ? Icons.history_rounded
                            : Icons.check_circle_outline,
                        size: 14,
                        color: m.undone
                            ? cs.onSurfaceVariant
                            : cs.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          m.undone ? '$item • dibatalkan' : item,
                          style: TextStyle(
                            fontSize: 11,
                            color: m.undone
                                ? cs.onSurfaceVariant
                                : cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            // (Tombol aksi tidak di sini — dirender di bawah bubble.)
          ],
        ),
      ),
    );
  }

  /// Field edit pesan user (menggantikan teks saat mode edit) + tombol
  /// Batal / Simpan. Simpan dengan teks sama = keluar tanpa kirim ulang;
  /// teks kosong ditolak dengan toast (lihat [_saveEdit]).
  Widget _editField(ColorScheme cs, int index, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _editController,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(fontSize: 14, color: textColor, height: 1.35),
          cursorColor: cs.primary,
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _cancelEdit,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Batal', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 4),
            FilledButton.tonal(
              onPressed: () => _saveEdit(index),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Simpan', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  /// Baris aksi kecil DI BAWAH bubble (rata sisi bubble via Column parent):
  /// salin + edit untuk pesan user; retry + undo untuk balasan asisten.
  /// Selama [_busy]/transkripsi tidak ada tombol sama sekali (kecuali salin
  /// yang aman kapan pun); mode edit menyembunyikan baris ini.
  Widget _bubbleActions(ColorScheme cs, int index, _AgentMsg m) {
    // Mode edit: field Batal/Simpan sudah ada di dalam bubble.
    if (_editingIndex == index) return const SizedBox.shrink();
    // Aksi berbahaya disembunyikan saat AI bekerja / merekam suara.
    final locked = _busy || _voice.isTranscribing;
    final isLast = index == _messages.length - 1;
    final actions = <Widget>[];
    if (m.isUser) {
      actions.add(
        _bubbleAction(
          cs: cs,
          icon: Icons.content_copy_rounded,
          tooltip: 'Salin prompt',
          onTap: () => _copyText(m.text),
        ),
      );
      // Edit: hanya pesan user terakhir & tidak terkunci.
      if (!locked && index == _lastUserIndex()) {
        actions.add(
          _bubbleAction(
            cs: cs,
            icon: Icons.edit_outlined,
            tooltip: 'Edit & kirim ulang',
            onTap: () => _beginEdit(index),
          ),
        );
      }
    } else {
      // Retry: hanya balasan terakhir (termasuk error) & tidak terkunci.
      if (!locked && isLast) {
        actions.add(
          _bubbleAction(
            cs: cs,
            icon: Icons.refresh_rounded,
            tooltip: 'Coba lagi',
            onTap: () => _retry(index),
          ),
        );
      }
      // Undo: mengikuti aturan [_canUndo] (tanpa redo).
      if (!locked && _canUndo(index)) {
        actions.add(
          _bubbleAction(
            cs: cs,
            icon: Icons.undo_rounded,
            tooltip: 'Urungkan perubahan draf',
            onTap: () => _undo(index),
          ),
        );
      }
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    // Rapat di bawah bubble, sedikit inset dari tepi sisi bubble.
    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        right: m.isUser ? 6 : 0,
        left: m.isUser ? 0 : 6,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
  }

  Widget _bubbleAction({
    required ColorScheme cs,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  /// Drawer riwayat & pengaturan — meluncur dari kanan MENUTUPI seluruh
  /// panel (opaque, tanpa scrim); pola `AiChatDrawer` versi compact.
  /// Radius 16 di SEMUA sudut agar mengikuti kartu panel — radius kiri saja
  /// membuat sudut kanan drawer persegi menutupi sudut kartu hingga terlihat
  /// terpotong oleh clip parent.
  /// Pengaturan memakai dialog API key (bukan pindah layar) agar alur
  /// edit form tidak terganggu.
  Widget _drawer(ColorScheme cs) {
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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

  /// Pill prompt satu warna ala Gemini (`ChatInputBar`): field teks menyatu
  /// dengan card prompt (tanpa kotak dalam beda warna), memakai
  /// `cs.surface` di kedua mode agar senada dengan bubble AI.
  Widget _inputPill(ColorScheme cs) {
    final canSend =
        _input.text.trim().isNotEmpty || _pendingAttachments.isNotEmpty;
    final enabled = !_busy && !_voice.isTranscribing;

    // Pill mengikuti warna bubble AI (cs.surface) — pola ChatInputBar.
    final pillColor = cs.surface;

    return Container(
      key: _inputBarKey,
      padding: EdgeInsets.fromLTRB(
        8,
        _pendingAttachments.isNotEmpty ? 12 : 6,
        8,
        6,
      ),
      decoration: BoxDecoration(
        color: pillColor,
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
          // Field teks transparan menyatu dengan pill (tanpa Container
          // dalam) — InputDecoration border none + filled false.
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, right: 8),
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
              decoration: InputDecoration(
                hintText: 'Tulis perintah untuk draf...',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(4, 10, 8, 8),
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: cs.onSurfaceVariant,
                ),
              ),
              style: TextStyle(fontSize: 15, color: cs.onSurface),
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

/// Bubble thinking AFA: tiga titik berdenyut + label status yang berganti
/// ("memahami perintah" → "menyusun draf") selama AI bekerja.
///
/// Stateful mandiri dengan [AnimationController] + [Timer] sendiri sehingga
/// animasi jalan mulus tanpa me-rebuild panel; timer & controller selalu
/// dibatalkan di [dispose] (aman bila panel ditutup saat AI masih bekerja).
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  static const _labels = ['AFA memahami perintah…', 'AFA menyusun draf…'];

  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();
  Timer? _labelTimer;
  int _phase = 0;

  @override
  void initState() {
    super.initState();
    _labelTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (mounted) setState(() => _phase = (_phase + 1) % _labels.length);
    });
  }

  @override
  void dispose() {
    _labelTimer?.cancel();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: softShadow(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _dots,
            builder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                    child: Opacity(
                      opacity: 0.25 + 0.75 * ((_dots.value + i / 3) % 1.0),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _labels[_phase],
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}