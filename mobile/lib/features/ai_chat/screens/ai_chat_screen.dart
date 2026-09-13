import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/ai_chat_history_service.dart';
import 'package:form_up/core/services/ai_form_context_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/gemini_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:form_up/features/ai_chat/controllers/mention_highlight_controller.dart';
import 'package:form_up/features/ai_chat/controllers/typing_stream.dart';
import 'package:form_up/features/ai_chat/models/ai_attachment.dart';
import 'package:form_up/features/ai_chat/models/chat_message.dart';
import 'package:form_up/features/ai_chat/utils/action_json_parse.dart';
import 'package:form_up/features/ai_chat/widgets/ai_chat_drawer.dart';
import 'package:form_up/features/ai_chat/widgets/ai_model_picker.dart';
import 'package:form_up/features/ai_chat/widgets/api_key_dialog.dart';
import 'package:form_up/features/ai_chat/widgets/chat_bubble.dart';
import 'package:form_up/features/ai_chat/widgets/chat_empty_state.dart';
import 'package:form_up/features/ai_chat/widgets/chat_input_bar.dart';
import 'package:form_up/features/ai_chat/widgets/pending_action_bar.dart';

part 'parts/chat_sessions.dart';
part 'parts/chat_mentions.dart';
part 'parts/chat_messaging.dart';
part 'parts/chat_history_ops.dart';

/// Layar chat AI — thin screen: state + scroll + komposisi UI.
/// Logic sesi ada di parts/chat_sessions.dart,
/// logic @mention di parts/chat_mentions.dart,
/// logic kirim/aksi AI di parts/chat_messaging.dart.
class AiChatScreen extends StatefulWidget {
  final bool embedded;

  /// Anchor tur panduan untuk field prompt chat.
  static final inputTourKey = GlobalKey();

  /// Form yang otomatis di-mention saat screen dibuka (shortcut dari
  /// kelola soal) — field prompt langsung berisi @JudulForm.
  final int? initialFormId;

  /// Prompt yang langsung diisi ke field setelah mention (siap kirim
  /// oleh user — TIDAK otomatis dikirim).
  final String? initialPrompt;

  const AiChatScreen({
    super.key,
    this.embedded = false,
    this.initialFormId,
    this.initialPrompt,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = MentionHighlightController();
  final _scroll = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // Focus field chat dipegang sendiri agar keyboard TIDAK otomatis terbuka
  // saat dialog/popup (ganti model, konfirmasi undo, retry, drawer sesi)
  // ditutup — Flutter me-restore fokus ke node terakhir bila tidak di-unfocus.
  final _chatFocus = FocusNode();
  final List<ChatMessage> _messages = [];
  List<ChatSession> _sessions = [];
  String? _currentSessionId;
  bool _streaming = false;
  StreamSubscription<String>? _sub;

  /// True selama persiapan kirim (bangun konteks form via network) SEBELUM
  /// streaming dimulai. Menutup celah double-tap tombol kirim yang
  /// menimbulkan 2 request paralel dan menghabiskan kuota.
  bool _sending = false;

  // Pesan bot + buffer yang sedang streaming (dipakai tombol stop).
  ChatMessage? _streamingMsg;
  StringBuffer? _streamingBuffer;

  // Token pembatalan request aktif — tombol stop menutup koneksi HTTP
  // lewat token ini agar request yang menggantung langsung dibatalkan.
  GeminiCancel? _activeCancel;

  // Mesin efek ketik: menampilkan chunk per kata (bukan burst) agar
  // user melihat AI benar-benar sedang mengetik.
  TypingStream? _typingStream;

  // True saat aksi pending sedang dieksekusi (tombol Terima).
  bool _actionWorking = false;

  // Draft input per sesi: teks field tersimpan per session id, tidak
  // ikut berpindah saat ganti sesi (in-memory saja).
  final Map<String, String> _drafts = {};

  // Konteks form terakhir di sesi aktif (hasil @mention). Dibawa ulang ke
  // pesan lanjutan yang tidak ada mention-nya (mis. "edit soal sebelumnya")
  // agar AI tetap punya id soal — tanpa ini AI hanya bisa add_questions.
  // Ikut dipersist per sesi (lihat ChatSession.formContext).
  String? _lastFormContext;

  // Form aktif sesi ini: form yang dibuat oleh AI (aksi diterima) atau
  // terakhir di-mention user. Pesan lanjutan otomatis memakai konteks form
  // ini tanpa perlu mention ulang; mention hanya untuk PINDAH form.
  // Ikut dipersist per sesi (lihat ChatSession.activeFormId).
  int? _activeFormId;

  // Agent: @mention & model picker
  List<FormData> _allForms = [];
  List<FormData> _mentionCandidates = [];
  String _mentionQuery = '';
  int _mentionStart = -1;
  bool _isMentionActive = false;

  // id -> label yang tampil di text field (dipotong 1-2 kata)
  final Map<int, String> _pickedMentions = {};
  String _lastText = '';

  bool _isLoadingForms = false;
  bool _formsLoadFailed = false;
  String? _formsLoadError;

  // FAB scroll-to-bottom: muncul jika user sudah scroll ke atas > 1 layar & belum di paling bawah
  bool _showFab = false;

  // 2: panel riwayat collapsible di desktop (default tersembunyi).
  bool _historyOpen = false;

  /// Inset kanan FAB agar menempel kolom chat 860 di desktop.
  /// Phone/tablet sempit: tetap 16.
  double _fabRightInset(BuildContext context) {
    if (!isDesktopWidth(context)) return 16;
    final w = MediaQuery.sizeOf(context).width;
    var chatW = w;
    if (isExpanded(context) && _historyOpen) {
      chatW -= (isWide(context) ? 360 : 320) + 1;
    }
    final inset = (chatW - 860) / 2 + 16;
    return inset < 16 ? 16 : inset;
  }

  // Settle-scroll: setelah lompat ke dasar, maxScrollExtent bisa masih
  // estimasi (SliverList lazy — bubble bawah belum dibangun) sehingga
  // satu lompatan mendarat di tengah. Loop ini mengoreksi beberapa frame
  // sampai tinggi konten stabil, dan dibatalkan saat user drag sendiri.
  bool _settleActive = false;
  int _settleFramesLeft = 0;

  // Tinggi input bar terukur (bisa membesar saat field multiline /
  // hint mention tampil) — dipakai agar FAB & padding list mengikuti.
  double _inputBarHeight = 80;
  final _inputBarKey = GlobalKey();

  // Lampiran pending sebelum dikirim (maks 3 @10MB)
  List<AiAttachment> _pendingAttachments = [];

  // Voice dikte
  bool _isListening = false;
  SpeechToText? _speech;

  Future<void> pickAttachments() async {
    if (_streaming || _sending) return;
    if (_pendingAttachments.length >= AiAttachment.maxCount) {
      showAuthToast(context, 'Maksimal ${AiAttachment.maxCount} file', isError: true);
      return;
    }
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: AiAttachment.allowedExtensions,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final newItems = <AiAttachment>[];
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        if (bytes.length > AiAttachment.maxBytesPerFile) {
          showAuthToast(context, '${f.name} melebihi 10MB', isError: true);
          continue;
        }
        final ext = f.name.split('.').last.toLowerCase();
        final mime = AiAttachment.mimeFromExtension(ext);
        newItems.add(AiAttachment(
          id: DateTime.now().microsecondsSinceEpoch.toString() + f.name,
          name: f.name,
          mime: mime,
          sizeBytes: bytes.length,
          bytes: bytes,
        ));
        if (_pendingAttachments.length + newItems.length >= AiAttachment.maxCount) break;
      }
      if (_pendingAttachments.length + newItems.length > AiAttachment.maxCount) {
        showAuthToast(context, 'Maksimal ${AiAttachment.maxCount} file', isError: true);
        newItems.removeRange(AiAttachment.maxCount - _pendingAttachments.length, newItems.length);
      }
      if (newItems.isNotEmpty) setState(() => _pendingAttachments = [..._pendingAttachments, ...newItems]);
    } catch (e) {
      showAuthToast(context, 'Gagal memilih file: $e', isError: true);
    }
  }

  void removePendingAttachment(String id) {
    setState(() => _pendingAttachments.removeWhere((a) => a.id == id));
  }

  Future<void> toggleVoice() async {
    if (_isListening) {
      try {
        await _speech?.stop();
      } catch (_) {}
      if (mounted) setState(() => _isListening = false);
      return;
    }
    try {
      if (!isDesktopPlatform) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          if (mounted) showAuthToast(context, 'Izin mikrofon ditolak', isError: true);
          return;
        }
      }
      _speech ??= SpeechToText();
      final available = await _speech!.initialize(
        onError: (e) {
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            if (mounted && _isListening) setState(() => _isListening = false);
          }
        },
      );
      if (!available) {
        if (mounted) {
          if (isDesktopPlatform) {
            showAuthToast(
              context,
              'Dikte Windows belum aktif. Aktifkan di Pengaturan Windows > Waktu & Bahasa > Ucapan, instal paket Indonesia, lalu coba lagi.',
              isError: true,
            );
          } else {
            showAuthToast(context, 'Dikte tidak tersedia di perangkat ini', isError: true);
          }
        }
        return;
      }
      setState(() => _isListening = true);
      await _speech!.listen(
        onResult: (result) {
          final recognized = result.recognizedWords;
          if (recognized.isNotEmpty) {
            final sel = _controller.selection;
            final text = _controller.text;
            final before = text.substring(0, sel.start >= 0 ? sel.start : text.length);
            final after = text.substring(sel.end >= 0 ? sel.end : text.length);
            final insert = (before.isEmpty || before.endsWith(' ') ? '' : ' ') + recognized;
            final newText = before + insert + (after.isEmpty ? '' : ' $after');
            _controller.text = newText;
            _controller.selection = TextSelection.collapsed(offset: (before + insert).length);
          }
          if (result.finalResult) {
            if (mounted) setState(() => _isListening = false);
          }
        },
        localeId: 'id_ID',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isListening = false);
        showAuthToast(context, 'Gagal dikte: $e', isError: true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _scroll.addListener(_onScroll);
    loadSessions();
    loadAllForms().then((_) async {
      // Shortcut dari kelola soal / analisis: otomatis mention form tersebut,
      // lalu isi prompt siap kirim (user yang menekan kirim sendiri).
      final id = widget.initialFormId;
      if (id != null && mounted) {
        await applyInitialMention(id);
        final prompt = widget.initialPrompt;
        if (prompt != null && prompt.isNotEmpty && mounted) {
          setState(() {
            _controller.text = '${_controller.text}$prompt';
            _lastText = _controller.text;
          });
        }
      }
    });
    // Error key hanya muncul saat user menekan kirim (lihat sendWithText),
    // bukan saat membuka layar.
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _chatFocus.dispose();
    _scroll.dispose();
    _activeCancel?.cancel();
    _typingStream?.dispose();
    _sub?.cancel();
    _speech?.cancel();
    for (final m in _messages) {
      m.disposeStream();
    }
    super.dispose();
  }

  /// Tutup keyboard chat. Dipanggil di SEMUA aksi tombol yang tidak
  /// butuh mengetik (ganti model, retry, terima/tolak, stop, undo/redo,
  /// ganti/hapus sesi) agar keyboard tidak terbuka sendiri.
  /// Sengaja TIDAK dipanggil di send() — sehabis kirim user biasa lanjut mengetik.
  void _dismissKeyboard() {
    if (_chatFocus.hasFocus) _chatFocus.unfocus();
  }

  /// True jika user sedang di (atau sangat dekat dengan) dasar chat.
  /// Auto-follow saat streaming HANYA berjalan bila ini true —
  /// user yang sengaja scroll ke atas tidak dirampas posisinya.
  bool get _isAtBottom {
    if (!_scroll.hasClients) return true;
    final pos = _scroll.position;
    return pos.maxScrollExtent - _scroll.offset <= 80;
  }

  /// Ikuti teks streaming gaya "magnet": lompat ke dasar SETELAH frame
  /// teks baru selesai di-layout. Kalau di-jump sebelum layout, targetnya
  /// masih nilai lama dan list perlahan tertinggal sampai magnet lepas
  /// sendiri padahal user tidak pernah scroll.
  void _followStream() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// Listener scroll: kontrol visibilitas FAB scroll-to-bottom.
  /// Muncul setiap user TIDAK di paling bawah (toleransi 32px),
  /// tapi hanya jika konten melebihi 1 layar (ada yang bisa di-scroll).
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.viewportDimension <= 0 || !pos.hasContentDimensions) return;
    final distanceFromBottom = pos.maxScrollExtent - _scroll.offset;
    final contentTallerThanOneScreen =
        pos.maxScrollExtent > pos.viewportDimension + 8;
    final show =
        _messages.isNotEmpty &&
        contentTallerThanOneScreen &&
        distanceFromBottom > 32;
    if (show != _showFab && mounted) setState(() => _showFab = show);
  }

  void _scrollToBottom({bool immediate = false}) {
    if (immediate) {
      // Lompat SEKARANG ke dasar versi sekarang, lalu settle: koreksi
      // tiap frame selama maxScrollExtent masih berubah (layout awal
      // list + bubble markdown yang baru selesai diukur). Tanpa settle,
      // lompatan pertama bisa mendarat di tengah chat.
      _settleActive = true;
      _settleFramesLeft = 24;
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _settleJump());
      return;
    }
    // PENTING: maxScrollExtent SAAT INI belum termasuk bubble yang baru
    // di-add via setState (belum di-layout) — animasi ke nilai lama membuat
    // list tampak "diam di tempat". Karena itu target dihitung di callback
    // pasca-frame, ketika item baru sudah masuk layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Satu langkah settle: lompat ke dasar terkini, lalu lanjut ke frame
  /// berikutnya selama extent masih berubah (atau jatah frame belum habis).
  void _settleJump() {
    if (!mounted || !_settleActive || !_scroll.hasClients) return;
    final before = _scroll.position.maxScrollExtent;
    _scroll.jumpTo(before);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_settleActive || !_scroll.hasClients) return;
      _settleFramesLeft--;
      final changed = (_scroll.position.maxScrollExtent - before).abs() > 0.5;
      if (changed && _settleFramesLeft > 0) _settleJump();
    });
  }

  /// Aksi FAB: sekali ketuk langsung ke chat terbaru (paling bawah)
  /// sampai FAB hilang. Double-jump (sekarang + pasca-frame) menjamin
  /// extent terbaru ikut tercapai walau layout baru selesai di frame berikut.
  void _jumpToBottom() {
    if (mounted && _showFab) setState(() => _showFab = false);
    // Tap FAB = aksi user → hentikan settle agar tidak saling rebutan.
    _settleActive = false;
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
      _onScroll();
      if (mounted &&
          _scroll.position.maxScrollExtent - _scroll.offset <= 32 &&
          _showFab) {
        setState(() => _showFab = false);
      }
    });
  }

  /// G6: drawer sesi dipakai ulang sebagai panel permanen di layar lebar.
  AiChatDrawer _buildSessionDrawer(BuildContext context) {
    return AiChatDrawer(
      sessions: _sessions,
      currentSessionId: _currentSessionId,
      modelDisplay: GeminiService.selectedModelDisplay,
      onNewSession: newSession,
      onSelectSession: switchSession,
      onDeleteSession: deleteSession,
      onClearAll: clearAllSessions,
      onOpenSettings: () => AppRouter.of(context).push(AppPage.aiSettings),
      // Panel kanan: tombol X menutup panel (bukan pop route).
      onClosePanel: isExpanded(context)
          ? () => setState(() => _historyOpen = false)
          : null,
    );
  }

  /// G6/2: phone = chat full-bleed seperti sekarang; expanded (≥840) = chat +
  /// panel sesi di KANAN (navigasi app sudah di kiri), panel bisa di-toggle.
  /// Tidak menyentuh isi Stack chat.
  Widget _adaptiveChatBody(Widget chat) {
    if (!isExpanded(context)) return chat;
    if (!_historyOpen) return chat;
    // Tanpa divider: panel menempel bersih ke area chat.
    return Row(
      children: [
        Expanded(child: chat),
        SizedBox(
            width: isWide(context) ? 360 : 320,
            child: _buildSessionDrawer(context)),
      ],
    );
  }

  Widget _buildHeader(ColorScheme cs, double topInset) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.55, 0.8, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(8, topInset + 6, 8, 28),
      child: Row(
        children: [
          if (widget.embedded && !isExpanded(context))
            IconButton(
              icon: Icon(Icons.menu, color: cs.onSurface),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            )
          else if (!widget.embedded)
            IconButton(
              icon: Icon(Icons.arrow_back, color: cs.onSurface),
              onPressed: () => AppRouter.of(context).pop(),
            ),
          // Mobile (<600) : pemilihan model di kiri atas; tablet/desktop di dalam field
          if (!isTablet(context))
            Flexible(
              child: AiModelPicker(onChanged: () {
                _dismissKeyboard();
                setState(() {});
              }),
            ),
          const Spacer(),
          // Tombol toggle panel dipindah ke overlay pojok kanan Scaffold agar tidak tertutup gradient
        ],
      ),
    );
  }

  Widget _buildChatStack(ColorScheme cs, double topInset) {
    return Stack(
      children: [
        // Header gradient khusus chat — berada di belakang sidebar/history (di dalam chat saja)
        Positioned(top: 0, left: 0, right: 0, child: _buildHeader(cs, topInset)),
        Positioned.fill(
          child: _messages.isEmpty
              ? ChatEmptyState(
                  topPadding: topInset + 96,
                  onQuickSend: (text) {
                    _controller.text = text;
                    send();
                  },
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if ((n is ScrollStartNotification && n.dragDetails != null) ||
                        (n is ScrollUpdateNotification && n.dragDetails != null)) {
                      _settleActive = false;
                    }
                    return false;
                  },
                  child: LayoutBuilder(
                    builder: (ctx, cons) {
                      // Desktop: lebar chat = window - sidebar - history.
                      // centerPad lama pakai MediaQuery (window), jadi saat
                      // sidebar/history terbuka, chat jadi gepeng (220px).
                      // Samakan dengan field prompt: center 860 di dalam chat.
                      // Tambah margin horizontal sedikit untuk tablet/desktop.
                      final w = cons.maxWidth;
                      final isWideLayout = isTablet(ctx);
                      final baseSide = isWideLayout ? 24.0 : 16.0;
                      final side = w >= 860 ? (w - 860) / 2 + (isWideLayout ? 12 : 0) : baseSide;
                      final pad = EdgeInsets.fromLTRB(side, topInset + 96, side, _inputBarHeight + 36);
                      return ListView.separated(
                        controller: _scroll,
                        padding: pad,
                    itemCount: _messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final m = _messages[i];
                      final isUser = m.role == 'user';
                      return ChatBubble(
                        message: m,
                        streaming: _streaming,
                        isLast: i == _messages.length - 1,
                        actionsEnabled: !_streaming && !_sending,
                        onRetry: () => retryMessage(m),
                        onContinue: () => continueTruncated(m),
                        onUndo: () => undoActionChange(m),
                        onRedo: () => redoActionChange(m),
                        onUserLongPress: isUser ? () => showMessageMenu(m) : null,
                        onPromptRetry: isUser ? () => retryUserMessage(m) : null,
                        onPromptEdit: isUser ? () => showEditMessageDialog(m) : null,
                        onPromptCopy: isUser ? () => copyUserMessage(m) : null,
                      );
                    },
                  );
                    },
                  ),
                ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              height: 170,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
                    Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.50),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  key: _inputBarKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pendingActionMessage != null)
                      PendingActionBar(
                        action: pendingActionMessage!.actionJson!,
                        isWorking: _actionWorking,
                        enabled: !_streaming && !_sending,
                        onAccept: acceptPendingAction,
                        onReject: rejectPendingAction,
                      ),
                    Container(
                      key: AiChatScreen.inputTourKey,
                      child: ChatInputBar(
                        textController: _controller,
                        focusNode: _chatFocus,
                        streaming: _streaming,
                        sending: _sending,
                        mentionActive: _isMentionActive,
                        mentionCandidates: _mentionCandidates,
                        mentionQuery: _mentionQuery,
                        isLoadingForms: _isLoadingForms,
                        formsLoadFailed: _formsLoadFailed,
                        formsLoadError: _formsLoadError,
                        pickedMentionCount: _pickedMentions.length,
                        hasAtSign: _controller.text.contains('@'),
                        onSend: send,
                        onStop: stopGeneration,
                        onSelectMention: selectMention,
                        onRetryLoadForms: () => loadAllForms(force: true),
                        attachments: _pendingAttachments,
                        onPickFiles: pickAttachments,
                        onRemoveAttachment: removePendingAttachment,
                        isListening: _isListening,
                        onMicPressed: toggleVoice,
                        onModelChanged: () {
                          _dismissKeyboard();
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: _fabRightInset(context),
          bottom: _inputBarHeight + 10,
          child: IgnorePointer(
            ignoring: !_showFab,
            child: AnimatedOpacity(
              opacity: _showFab ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: FloatingActionButton.small(
                heroTag: 'aiChatScrollToBottom',
                backgroundColor: cs.surface,
                foregroundColor: cs.primary,
                elevation: 3,
                onPressed: _jumpToBottom,
                child: const Icon(Icons.arrow_downward, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final h = _inputBarKey.currentContext?.size?.height;
      if (h != null && mounted && (h - _inputBarHeight).abs() > 0.5) {
        setState(() => _inputBarHeight = h);
      }
    });
    return Scaffold(
      key: _scaffoldKey,
      onDrawerChanged: (open) {
        if (open) _dismissKeyboard();
      },
      drawer: isExpanded(context) ? null : _buildSessionDrawer(context),
      body: Stack(
        children: [
          // Chat + history panel — header & bottom gradient berada di dalam chat saja,
          // sehingga sidebar kiri (Drive) & panel kanan (Riwayat) berada di depan gradient.
          Positioned.fill(
            child: _adaptiveChatBody(_buildChatStack(cs, topInset)),
          ),
          // Tombol buka panel di pojok kanan — hanya saat panel tertutup.
          // Saat panel terbuka, tombol tertimpa sidebar kanan; yang tampil
          // hanya tombol Tutup di dalam drawer (AiChatDrawer onClosePanel).
          // Tampilkan untuk mode embedded maupun standalone di desktop.
          if (isExpanded(context) && !_historyOpen)
            Positioned(
              top: topInset + 6,
              right: 8,
              child: SafeArea(
                top: false,
                child: IconButton(
                  tooltip: 'Buka panel riwayat',
                  icon: Icon(Icons.menu, color: cs.onSurface),
                  onPressed: () => setState(() => _historyOpen = true),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
