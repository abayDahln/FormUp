import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/ai_chat_history_service.dart';
import 'package:form_up/core/services/ai_form_context_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/gemini_service.dart';
import 'package:form_up/core/widgets/ai_chat_icon.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/ai_chat/controllers/mention_highlight_controller.dart';
import 'package:form_up/features/ai_chat/controllers/typing_stream.dart';
import 'package:form_up/features/ai_chat/models/chat_message.dart';
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

/// Layar chat AI — thin screen: state + scroll + komposisi UI.
/// Logic sesi ada di parts/chat_sessions.dart,
/// logic @mention di parts/chat_mentions.dart,
/// logic kirim/aksi AI di parts/chat_messaging.dart.
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

  bool _isLoadingForms = false;
  bool _formsLoadFailed = false;
  String? _formsLoadError;

  // FAB scroll-to-bottom: muncul jika user sudah scroll ke atas > 1 layar & belum di paling bawah
  bool _showFab = false;

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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _scroll.addListener(_onScroll);
    loadSessions();
    loadAllForms();
    // Toast sekali saat baru membuka app & membuka screen AI chat jika key belum diatur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_shownInitialMissingKeyToast && !GeminiService.hasKey && mounted) {
        _shownInitialMissingKeyToast = true;
        showAuthToast(
          context,
          'Api Key belum diatur. Tambahkan sekarang di pengaturan',
          isError: true,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scroll.dispose();
    _activeCancel?.cancel();
    _typingStream?.dispose();
    _sub?.cancel();
    for (final m in _messages) {
      m.disposeStream();
    }
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    // Gaya Gemini: ListView full-bleed di belakang header & input,
    // dengan gradient fade di atas dan bawah agar scroll memudar mulus.
    final topInset = MediaQuery.of(context).padding.top;
    // Ukur tinggi input bar tiap frame; saat field membesar (multiline /
    // hint mention), FAB & padding list ikut naik mengikuti.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final h = _inputBarKey.currentContext?.size?.height;
      if (h != null &&
          mounted &&
          (h - _inputBarHeight).abs() > 0.5) {
        setState(() => _inputBarHeight = h);
      }
    });
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kAppBg,
      drawer: AiChatDrawer(
        sessions: _sessions,
        currentSessionId: _currentSessionId,
        modelDisplay: GeminiService.selectedModelDisplay,
        onNewSession: newSession,
        onSelectSession: switchSession,
        onDeleteSession: deleteSession,
        onClearAll: clearAllSessions,
        onOpenSettings: () =>
            AppRouter.of(context).push(AppPage.aiSettings),
      ),
      body: Stack(
        children: [
          // --- 3. Chat list extends behind header & input ---
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
                      // User mulai drag sendiri → batalkan settle-scroll
                      // agar magnet tidak merebut kembali posisinya.
                      if ((n is ScrollStartNotification &&
                              n.dragDetails != null) ||
                          (n is ScrollUpdateNotification &&
                              n.dragDetails != null)) {
                        _settleActive = false;
                      }
                      return false;
                    },
                    child: ListView.separated(
                    controller: _scroll,
                    // Padding bawah mengikuti tinggi input bar + gap kecil,
                    // agar bubble terakhir tetap terlihat di atas field
                    // saat field membesar (multiline). Default: 80 + 36 = 116.
                    padding: EdgeInsets.fromLTRB(
                      16,
                      topInset + 96,
                      16,
                      _inputBarHeight + 36,
                    ),
                    itemCount: _messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final m = _messages[i];
                      return ChatBubble(
                        message: m,
                        streaming: _streaming,
                        isLast: i == _messages.length - 1,
                        onRetry: () => retryMessage(m),
                      );
                    },
                  ),
                ),
          ),
          // --- 2. Bottom gradient TINGGI + Gemini pill input ---
          // Zona fade 110px (transparan -> solid) + bodi solid kAppBg
          // di belakang pill, agar chat memudar mulus jauh sebelum input.
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        kAppBg.withValues(alpha: 0),
                        kAppBg.withValues(alpha: 0.50),
                        kAppBg,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                // Bar persetujuan aksi AI (Terima/Tolak) + input prompt
                // dibungkus satu Column berkunci agar tinggi KEDUANYA
                // terukur — FAB & padding list ikut menyesuaikan.
                Column(
                  key: _inputBarKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pendingActionMessage != null)
                      PendingActionBar(
                        action: pendingActionMessage!.actionJson!,
                        isWorking: _actionWorking,
                        onAccept: acceptPendingAction,
                        onReject: rejectPendingAction,
                      ),
                    ChatInputBar(
                      textController: _controller,
                      streaming: _streaming,
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
                      onClearMentions: () => setState(() {
                        _pickedMentions.clear();
                        _controller.mentionTokens = [];
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // FAB scroll-to-bottom: menempel tepat di atas input bar (kanan),
          // mengikuti tinggi input bar saat field membesar (multiline),
          // 1x klik langsung ke chat terbaru sampai FAB hilang.
          Positioned(
            right: 16,
            bottom: _inputBarHeight + 10,
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
                  onPressed: _jumpToBottom,
                  child: const Icon(Icons.arrow_downward, size: 20),
                ),
              ),
            ),
          ),
          // --- 1. Top header overlay: solid -> transparent, right side empty ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kAppBg,
                    kAppBg,
                    kAppBg.withValues(alpha: 0.85),
                    kAppBg.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.55, 0.8, 1.0],
                ),
              ),
              padding: EdgeInsets.fromLTRB(8, topInset + 6, 8, 28),
              child: Row(
                children: [
                  if (widget.embedded)
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black87),
                      onPressed: () =>
                          _scaffoldKey.currentState?.openDrawer(),
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.black87,
                      ),
                      onPressed: () => AppRouter.of(context).pop(),
                    ),
                  const AiChatIcon(
                    color: kAuthPrimary,
                    size: 20,
                    filled: true,
                  ),
                  const SizedBox(width: 8),
                  // Title sekaligus pemilih model AI (ketuk untuk ganti).
                  Flexible(
                    child: AiModelPicker(onChanged: () => setState(() {})),
                  ),
                  // Top-right sengaja dikosongkan (tanpa action buttons).
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
