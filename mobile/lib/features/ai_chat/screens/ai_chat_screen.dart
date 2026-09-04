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
import 'package:form_up/features/ai_chat/models/chat_message.dart';
import 'package:form_up/features/ai_chat/widgets/ai_chat_drawer.dart';
import 'package:form_up/features/ai_chat/widgets/ai_model_picker.dart';
import 'package:form_up/features/ai_chat/widgets/api_key_dialog.dart';
import 'package:form_up/features/ai_chat/widgets/chat_bubble.dart';
import 'package:form_up/features/ai_chat/widgets/chat_empty_state.dart';
import 'package:form_up/features/ai_chat/widgets/chat_input_bar.dart';

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

  /// Ikuti teks streaming: lompat sinkron ke extent terbaru (tanpa
  /// animasi per-chunk agar tidak jank/antrean animateTo).
  void _followStream() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
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
    if (!_scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
      return;
    }
    final target = _scroll.position.maxScrollExtent;
    if (immediate) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Aksi FAB: sekali ketuk langsung ke chat terbaru (paling bawah)
  /// sampai FAB hilang. Double-jump (sekarang + pasca-frame) menjamin
  /// extent terbaru ikut tercapai walau layout baru selesai di frame berikut.
  void _jumpToBottom() {
    if (mounted && _showFab) setState(() => _showFab = false);
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
                : ListView.separated(
                    controller: _scroll,
                    // Padding bawah pas setinggi input + sedikit gap agar
                    // card terakhir menempel tepat di atas field prompt
                    // (tanpa white space berlebih).
                    padding: EdgeInsets.fromLTRB(16, topInset + 96, 16, 116),
                    itemCount: _messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final m = _messages[i];
                      return ChatBubble(
                        message: m,
                        streaming: _streaming,
                        isLast: i == _messages.length - 1,
                        onRetry: () => retryMessage(m),
                        onRunAction: runBubbleAction,
                      );
                    },
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
                  onSelectMention: selectMention,
                  onRetryLoadForms: () => loadAllForms(force: true),
                  onClearMentions: () => setState(() {
                    _pickedMentions.clear();
                    _controller.mentionTokens = [];
                  }),
                ),
              ],
            ),
          ),
          // FAB scroll-to-bottom: menempel di atas field prompt (kanan),
          // 1x klik langsung ke chat terbaru sampai FAB hilang.
          Positioned(
            right: 16,
            bottom: 90,
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
