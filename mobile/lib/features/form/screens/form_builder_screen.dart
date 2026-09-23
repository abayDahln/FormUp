import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/utils/action_debouncer.dart';
import 'package:form_up/core/widgets/adaptive_fab.dart';
import 'package:form_up/core/widgets/app_toast.dart' hide showAuthToast;
import 'package:form_up/core/widgets/connection_error_view.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/loading_indicator.dart';
import 'package:form_up/core/widgets/loading_skeleton.dart';
import 'package:form_up/core/widgets/progress_indicator.dart' as progress;
import 'package:form_up/core/widgets/responsive.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/features/form/controllers/question_validation.dart';
import 'package:form_up/features/form/controllers/questions_persist.dart';
import 'package:form_up/features/form/widgets/ai_form_agent_panel.dart';
import 'package:form_up/features/form/widgets/ai_highlight_border.dart';
import 'package:form_up/features/form/widgets/form_settings_panel.dart';
import 'package:form_up/features/form/widgets/question_accordion_card.dart';
import 'package:form_up/features/form/widgets/question_import_mixin.dart';

/// Screen builder form all-in-one untuk tablet/desktop (pengganti dual
/// panel): SATU screen berisi kartu pengaturan form + daftar soal berbentuk
/// accordion (klik kartu → seluruh pengaturan soal terbuka di kartu itu).
/// Tombol Simpan hanya satu, di pojok kanan header — menyimpan keseluruhan
/// form (pengaturan → menciptakan formId bila form baru → lalu soal).
///
/// [questionsLocked] = true saat form sudah memiliki respons: daftar soal
/// hanya tampil (tambah/ubah/hapus/susun-ulang/impor dinonaktifkan),
/// pengaturan form tetap dapat diubah.
class FormBuilderScreen extends StatefulWidget {
  /// null = form baru.
  final int? formId;
  final bool questionsLocked;

  const FormBuilderScreen({super.key, this.formId, this.questionsLocked = false});

  @override
  State<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends State<FormBuilderScreen>
    with QuestionImportMixin {
  final GlobalKey<FormSettingsPanelState> _settingsKey =
      GlobalKey<FormSettingsPanelState>();
  final GlobalKey<AiFormAgentPanelState> _agentKey =
      GlobalKey<AiFormAgentPanelState>();
  final GlobalKey _addKey = GlobalKey();
  AppRouterDelegate? _router;

  final List<QuestionDraft> _questions = [];
  List<QuestionDraft> _baseline = [];
  bool _loadingQuestions = false;
  String? _questionsError;
  bool _savingQuestions = false;
  bool _importing = false;
  double? _progress;

  /// formId efektif — terisi setelah simpan pertama (form baru).
  int? _formId;

  /// Indeks kartu soal yang terbuka (accordion single-open).
  int? _openIndex;

  /// True = panel AI Form Agent tampil (kartu ketiga di ≥1400px, overlay
  /// panel kanan di lebar lebih sempit).
  bool _aiOpen = false;

  /// Highlight kerja AFA: indeks soal yang baru disentuh AI (border hijau
  /// berputar) + timer penghapus + key per kartu untuk auto-scroll.
  Set<int> _aiHighlight = {};
  Timer? _aiHighlightTimer;
  final Map<int, GlobalKey> _aiCardKeys = {};

  GlobalKey _aiCardKey(int i) =>
      _aiCardKeys.putIfAbsent(i, () => GlobalKey());

  /// Dipanggil panel AFA setiap satu aksi soal diterapkan: sorot kartunya
  /// + scroll ke sana. Highlight bertahan ±6 detik lalu padam sendiri.
  void _flashAiCards(List<int> indexes) {
    if (!mounted || indexes.isEmpty) return;
    _aiHighlightTimer?.cancel();
    // Buang key basi (daftar menyusut akibat hapus) agar ensureVisible tak
    // menyasar kartu yang salah.
    _aiCardKeys.removeWhere((k, _) => k >= _questions.length);
    final valid = indexes
        .where((i) => i >= 0 && i < _questions.length)
        .toSet();
    if (valid.isEmpty) return;
    setState(() => _aiHighlight = valid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _aiCardKeys[valid.first]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.15,
        );
      }
    });
    _aiHighlightTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _aiHighlight = {});
    });
  }

  // --- QuestionImportMixin accessors ---
  @override
  List<QuestionDraft> get importQuestions => _questions;
  @override
  int? get importFormId => _formId;
  @override
  bool get importBusy => _importing;
  @override
  void setImportBusy(bool value) => setState(() => _importing = value);

  @override
  void initState() {
    super.initState();
    _formId = widget.formId;
    if (_formId != null) _loadQuestions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= AppRouter.of(context);
    _router!.pushBackGuard(_guard);
  }

  @override
  void dispose() {
    _router?.popBackGuard();
    _aiHighlightTimer?.cancel();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  bool get _hasQuestionChanges {
    if (_questions.length != _baseline.length) return true;
    for (var i = 0; i < _questions.length; i++) {
      if (!_questions[i].sameAs(_baseline[i])) return true;
    }
    return false;
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loadingQuestions = true;
      _questionsError = null;
    });
    try {
      final questions = await FormService.getQuestions(
        _formId!,
        refresh: false,
      );
      if (!mounted) return;
      setState(() {
        _questions
          ..clear()
          ..addAll(draftsFromQuestions(questions));
        _baseline = [for (final q in _questions) q.copy()];
        _questionsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (AuthService.isConnectionError(e)) {
        setState(() => _questionsError = AuthService.errorMessage(e));
        return;
      }
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  /// Guard keluar gabungan: bila pengaturan dan/atau soal kotor → tawarkan
  /// simpan semua, buang, atau batal.
  Future<bool> _guard() async {
    // Panel AFA terbuka: Back menutup panel dulu, bukan keluar layar.
    if (_aiOpen) {
      setState(() => _aiOpen = false);
      return false;
    }
    final s = _settingsKey.currentState;
    if (s == null) return true;
    if (s.isSaving || _savingQuestions) return false;
    final dirtySettings = s.hasChanges;
    final dirtyQuestions =
        widget.questionsLocked ? false : _hasQuestionChanges;
    if (!dirtySettings && !dirtyQuestions) return true;
    if (!mounted) return false;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => ResponsiveDialog(
        child: AlertDialog(
          title: const Text(
            'Simpan perubahan?',
            style: TextStyle(fontFamily: kFontBold),
          ),
          content: const Text(
            'Ada perubahan pengaturan dan/atau soal yang belum tersimpan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text(
                'Buang',
                style: TextStyle(color: Color(0xFFC0392B)),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Simpan semua'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return false;
    if (choice == 'discard') return true;
    if (choice != 'save') return false;
    await _saveAll();
    if (!mounted) return false;
    final s2 = _settingsKey.currentState;
    return (s2 == null || !s2.hasChanges) && !_hasQuestionChanges;
  }

  /// Validasi seluruh draf soal SEBELUM menyentuh server. Bila ada error,
  /// buka kartu soal yang bermasalah dan tampilkan toast-nya.
  bool _validateQuestions() {
    for (var i = 0; i < _questions.length; i++) {
      final error = validateQuestionDraft(_questions[i]);
      if (error != null) {
        showAuthToast(context, 'Soal #${i + 1}: $error', isError: true);
        setState(() => _openIndex = i);
        return false;
      }
    }
    return true;
  }

  /// Satu tombol Simpan untuk seluruh form:
  /// 1) validasi semua soal (lokal, tanpa efek samping server);
  /// 2) simpan pengaturan via FormSettingsPanel (menciptakan formId bila
  ///    form baru, termasuk dialog yatim bila gagal);
  /// 3) persist soal + media via persistQuestions (hanya bila perlu).
  Future<void> _saveAll() async {
    if (!AppDebouncer.tryAcquire('form:saveAll')) return;
    final s = _settingsKey.currentState;
    if (s == null || s.isSaving || _savingQuestions) return;
    if (!_validateQuestions()) return;

    final bool created = _formId == null;
    final needQuestions = !widget.questionsLocked &&
        (_hasQuestionChanges || (created && _questions.isNotEmpty));

    setState(() => _savingQuestions = true);
    try {
      final id = await s.save();
      if (id == null || !mounted) return;
      setState(() => _formId = id);

      if (needQuestions) {
        final result = await persistQuestions(
          formId: id,
          questions: _questions,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          notify: (message, {isError = false}) {
            if (mounted) {
              showAuthToast(context, message, isError: isError);
            }
          },
        );
        if (!mounted) return;
        if (result.abortedOversize) {
          return; // soal belum selesai — jangan baseline.
        }
        setState(() => _baseline = [for (final q in _questions) q.copy()]);
        if (!_hasQuestionChanges) {
          showAppToast(
            context,
            _questions.isEmpty
                ? 'Semua soal dihapus'
                : '${_questions.length} soal disimpan',
            type: ToastType.success,
            title: 'Berhasil',
          );
        }
      }
      if (created && mounted) {
        showAuthToast(context, 'Form berhasil dibuat');
      }
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _savingQuestions = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _addQuestion() async {
    if (widget.questionsLocked) return;
    final draft = QuestionDraft(1, isRequired: true);
    setState(() {
      _questions.add(draft);
      _openIndex = _questions.length - 1;
    });
  }

  void _moveQuestion(int index, int delta) {
    if (widget.questionsLocked) return;
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _questions.length) return;
    setState(() {
      final q = _questions.removeAt(index);
      _questions.insert(newIndex, q);
      if (_openIndex == index) {
        _openIndex = newIndex;
      } else if (_openIndex == newIndex) {
        _openIndex = index;
      }
    });
  }

  Future<void> _deleteQuestion(int index) async {
    if (widget.questionsLocked) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Hapus Soal?',
          style: TextStyle(fontFamily: kFontBold),
        ),
        content: const Text(
          'Soal ini akan dihapus dari draf. Perubahan berlaku setelah kamu menekan Simpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Color(0xFFC0392B)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      final q = _questions.removeAt(index);
      q.dispose();
      if (_openIndex == index) {
        _openIndex = null;
      } else if (_openIndex != null && _openIndex! > index) {
        _openIndex = _openIndex! - 1;
      }
    });
  }

  Future<void> _clearAllQuestions() async {
    if (widget.questionsLocked) return;
    if (_savingQuestions || _importing || _questions.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Hapus Semua Soal?',
          style: TextStyle(fontFamily: kFontBold),
        ),
        content: const Text(
          'Semua soal di draf ini akan dihapus. Perubahan berlaku setelah kamu menekan Simpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Hapus Semua',
              style: TextStyle(color: Color(0xFFC0392B)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      for (final q in _questions) {
        q.dispose();
      }
      _questions.clear();
      _openIndex = null;
    });
  }

  /// Kembalikan draf soal ke data tersimpan terakhir (baseline server).
  /// Dipakai tombol "Reset Draf" di header Edit Form — mencegah konflik
  /// saat form sudah dikerjakan responden: draf lokal yang menyimpang
  /// dibuang dan diganti data server.
  Future<void> _resetQuestionsDraft() async {
    if (widget.questionsLocked) return;
    if (_savingQuestions || _importing) return;
    if (!_hasQuestionChanges) {
      showAuthToast(context, 'Tidak ada perubahan draf');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Reset Draf Soal?',
          style: TextStyle(fontFamily: kFontBold),
        ),
        content: const Text(
          'Perubahan soal yang belum disimpan akan dibuang dan dikembalikan ke data tersimpan terakhir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Form baru (belum ada di server): baseline = kosong.
    if (_formId == null) {
      setState(() {
        for (final q in _questions) {
          q.dispose();
        }
        _questions.clear();
        _baseline = [];
        _openIndex = null;
      });
      showAuthToast(context, 'Draf soal dikosongkan');
      return;
    }
    await _loadQuestions();
    if (!mounted) return;
    if (_questionsError == null) {
      showAuthToast(context, 'Draf soal dikembalikan ke data tersimpan');
    }
  }

  Widget _buildFab(ColorScheme cs) {
    final disabled = _savingQuestions || widget.questionsLocked;
    final aiFab = buildAiFab(
      key: null,
      heroTag: 'aiChatForFormBuilder',
      onPressed: _formId == null
          ? null
          : () => setState(() => _aiOpen = !_aiOpen),
      backgroundColor: _aiOpen ? cs.primaryContainer : cs.surface,
      foregroundColor: cs.primary,
      tooltip: _aiOpen ? 'Tutup AI Form Agent' : 'Buka AI Form Agent',
    );
    final Widget addFab = isTablet(context)
        ? buildExtendedAddFab(
            key: _addKey,
            onPressed: disabled ? null : _addQuestion,
            label: 'Tambah Soal',
            tooltip: 'Tambah Soal',
          )
        : buildCircleAddFab(
            key: _addKey,
            onPressed: disabled ? null : _addQuestion,
            tooltip: 'Tambah Soal',
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [aiFab, const SizedBox(height: 12), addFab],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final busy = _savingQuestions;
    final soalMenuEnabled =
        !busy && !_importing && !widget.questionsLocked;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: cs.outlineVariant)),
        title: Text(
          _formId == null ? "Buat Form" : "Edit Form",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () async {
            final allow = await _guard();
            if (!allow) return;
            if (!mounted) return;
            _router!.pop();
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: FilledButton(
              onPressed: busy ? null : _saveAll,
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: kPrimary.withValues(alpha: 0.6),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: LoadingIndicator.inline(),
                    )
                  : const Text('Simpan'),
            ),
          ),
          // Menu aksi soal (pindahan dari header "Kelola Soal" yang
          // dihapus): hapus semua, impor, unduh template, reset draf.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: cs.onSurface),
              tooltip: 'Opsi soal',
              enabled: !busy,
              onSelected: (value) async {
                switch (value) {
                  case 'clear':
                    await _clearAllQuestions();
                    break;
                  case 'import':
                    await importSoal();
                    break;
                  case 'template':
                    await downloadTemplate();
                    break;
                  case 'reset':
                    await _resetQuestionsDraft();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clear',
                  enabled: soalMenuEnabled && _questions.isNotEmpty,
                  child: const Row(
                    children: [
                      Icon(
                        Icons.delete_sweep_outlined,
                        size: 18,
                        color: Color(0xFFC0392B),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Hapus Semua Soal',
                        style: TextStyle(color: Color(0xFFC0392B)),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'import',
                  enabled: soalMenuEnabled && _formId != null,
                  child: const Row(
                    children: [
                      Icon(Icons.upload_file_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Impor Soal'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'template',
                  enabled: !busy,
                  child: const Row(
                    children: [
                      Icon(Icons.download_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Unduh Template Import'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'reset',
                  enabled: soalMenuEnabled,
                  child: const Row(
                    children: [
                      Icon(Icons.restart_alt_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Reset Draf Soal'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: progress.ProgressIndicator.linear(
            value: _progress,
            semanticsLabel: 'Menyimpan form',
          ),
        ),
        AuthBackground(
          plain: true,
          child: SafeArea(
            child: ValueListenableBuilder<ActiveRichEditor?>(
              valueListenable: activeRichEditor,
              builder: (context, active, _) {
                final toolbarVisible = active != null;
                // Dua kartu berdampingan di layar lebar: kiri pengaturan
                // form, kanan daftar soal. Di bawah breakpoint expanded,
                // susun vertikal (tetap satu screen, satu tombol Simpan).
                // Desktop fullscreen (≥1400) + sidebar AI terbuka: kedua
                // kartu bergeser ke kiri (konten diberi padding kanan
                // selebar sidebar) — sidebar pinned di Stack, tidak ikut
                // scroll. Lebar lebih sempit: overlay panel kanan.
                final twoColumn = isExpanded(context);
                final pushLayout = _aiOpen && isWide(context);
                final sidebarWidth = pushLayout
                    ? (MediaQuery.sizeOf(context).width * 0.30).clamp(
                        300.0,
                        420.0,
                      )
                    : 0.0;
                final w = MediaQuery.sizeOf(context).width;
                final EdgeInsets padding;
                if (pushLayout) {
                  // Konten di-center di zona kiri sidebar, dengan cap lebar
                  // + margin horizontal agar tidak menempel ke tepi window.
                  final zoneLeft = 24.0;
                  final avail = w - sidebarWidth - 16 - zoneLeft; // zona konten
                  final cap = twoColumn ? 1400.0 : 960.0;
                  final contentW = min(avail, cap);
                  final sideMargin = max(24.0, (avail - contentW) / 2);
                  padding = EdgeInsets.fromLTRB(
                    sideMargin,
                    topClearanceForRichToolbar(
                      toolbarVisible: toolbarVisible,
                    ),
                    sidebarWidth + 16 + sideMargin,
                    toolbarVisible ? 110 : 24,
                  );
                } else {
                  final capped = centerPad(
                    context,
                    base: EdgeInsets.fromLTRB(
                      22,
                      topClearanceForRichToolbar(
                        toolbarVisible: toolbarVisible,
                      ),
                      22,
                      0,
                    ),
                    maxWidth: twoColumn ? 1400 : 960,
                    wideMaxWidth: twoColumn ? 1400 : 960,
                  );
                  padding = capped.copyWith(bottom: toolbarVisible ? 110 : 24);
                }
                return SingleChildScrollView(
                  padding: padding,
                  child: SizedBox(
                    width: max(0, w - padding.left - padding.right),
                    child: twoColumn
                        ? _twoColumnContent(cs)
                        : _stackedContent(cs),
                  ),
                );
              },
            ),
          ),
        ),
        const FloatingRichToolbar(),
        // FAB (AI toggle + Tambah Soal): di kanan bawah; saat sidebar AI
        // terbuka, bergeser ke KIRI sidebar agar tidak menutupi panel.
        Positioned(
          right: _aiOpen && isWide(context)
              ? (MediaQuery.sizeOf(context).width * 0.30).clamp(300.0, 420.0) +
                    12
              : 16,
          bottom: 16,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _buildFab(cs),
          ),
        ),
        // Sidebar kanan AI Form Agent. Desktop fullscreen (≥1400): pinned,
        // konten digeser kiri via padding (pushLayout). Lebar lebih sempit
        // (tablet/mobile): overlay melayang di atas konten.
        if (_aiOpen)
          Positioned(
            top: 12,
            right: 12,
            bottom: 12,
            width: isWide(context)
                ? (MediaQuery.sizeOf(context).width * 0.30).clamp(300.0, 420.0)
                : 380,
            child: _aiCard(context, cs),
          ),
      ],
    );
  }

  /// Kartu **AFA (AI Form Agent)** — dipakai sidebar pinned maupun overlay.
  /// Hanya container ber-border tipis: header & kelola riwayat ada di dalam
  /// panel (agar konsisten dengan layar AI Chat).
  Widget _aiCard(BuildContext context, ColorScheme cs) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant, width: 1),
        ),
        child: AiFormAgentPanel(
          key: _agentKey,
          formId: _formId,
          settings: () => _settingsKey.currentState?.formController,
          // Mode kunci: agen tak diberi akses daftar soal.
          questions: widget.questionsLocked ? null : () => _questions,
          onChanged: () => setState(() {}),
          // Sorot + scroll ke soal yang baru dikerjakan AI (staggered).
          onQuestionsTouched: _flashAiCards,
          onClose: () => setState(() => _aiOpen = false),
        ),
      ),
    );
  }

  /// Daftar kartu accordion soal + state loading/empty (dipakai dua layout).
  List<Widget> _questionItems(ColorScheme cs) {
    if (_loadingQuestions) {
      // Mirror daftar kartu soal (bukan spinner tengah).
      return const [SkeletonList.questions(itemCount: 3)];
    }
    // Error koneksi saat daftar soal kosong: tampilkan retry, bukan "belum ada soal".
    if (_questionsError != null && _questions.isEmpty) {
      return [
        ConnectionErrorView(
          message: _questionsError!,
          onRetry: _loadQuestions,
          bare: true,
        ),
      ];
    }
    final items = <Widget>[
      if (widget.questionsLocked) _lockedBanner(cs),
      if (_questions.isEmpty) _emptyQuestionsCard(cs),
      for (var i = 0; i < _questions.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AiHighlightBorder(
            key: _aiCardKey(i),
            active: _aiHighlight.contains(i),
            child: QuestionAccordionCard(
              index: i,
              totalCount: _questions.length,
              draft: _questions[i],
              expanded: _openIndex == i,
              onToggle: () => setState(() {
                _openIndex = _openIndex == i ? null : i;
              }),
              onChanged: () => setState(() {}),
              onMoveUp: () => _moveQuestion(i, -1),
              onMoveDown: () => _moveQuestion(i, 1),
              onDelete: () => _deleteQuestion(i),
              readOnly: widget.questionsLocked,
            ),
          ),
        ),
    ];
    return items;
  }

  /// Banner info saat soal dikunci (form sudah memiliki respons).
  Widget _lockedBanner(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Soal dikunci — form sudah memiliki respons. '
                'Pengaturan form tetap dapat diubah.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Layout lebar: dua kartu berdampingan di sisi kiri, dengan AI sidebar
  /// mengambil porsi sekitar 30% untuk menjaga keseimbangan visual
  /// 35/35/30 ketika panel AI terbuka.
  Widget _twoColumnContent(ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KIRI: kartu pengaturan form.
        Expanded(
          flex: 35,
          child: FormSettingsPanel(
            key: _settingsKey,
            formId: _formId,
            scrollable: false,
            showSaveButton: false,
            centerContent: false,
          ),
        ),
        const SizedBox(width: 16),
        // KANAN: daftar item soal langsung (tanpa header "Kelola Soal" —
        // tombol aksi soal sudah pindah ke header Edit Form).
        Expanded(
          flex: 35,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._questionItems(cs),
            ],
          ),
        ),
      ],
    );
  }

  /// Layout sempit: kartu settings di atas, daftar soal di bawah.
  Widget _stackedContent(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSettingsPanel(
          key: _settingsKey,
          formId: _formId,
          scrollable: false,
          showSaveButton: false,
          centerContent: false,
        ),
        const SizedBox(height: 24),
        // Daftar item soal langsung (tanpa header "Kelola Soal").
        ..._questionItems(cs),
      ],
    );
  }

  Widget _emptyQuestionsCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.quiz_outlined, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'Belum ada soal. Ketuk "Tambah Soal" untuk membuat pertanyaan pertama.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
