import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/connection_error_view.dart';
import 'package:form_up/core/widgets/loading_skeleton.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:form_up/core/widgets/adaptive_fab.dart';
import 'package:form_up/core/widgets/loading_indicator.dart';
import 'package:form_up/core/widgets/progress_indicator.dart' as progress;
import 'package:form_up/core/utils/action_debouncer.dart';
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/widgets/onboarding_tour.dart';
import 'package:form_up/features/form/controllers/question_validation.dart';
import 'package:form_up/features/form/controllers/questions_persist.dart';
import 'package:form_up/features/form/widgets/ai_form_agent_panel.dart';
import 'package:form_up/features/form/widgets/ai_highlight_border.dart';
import 'package:form_up/features/form/widgets/question_confirm_dialogs.dart';
import 'package:form_up/features/form/widgets/question_import_mixin.dart';
import 'package:form_up/features/form/widgets/question_list_card.dart';
import 'package:form_up/features/form/widgets/questions_empty_state.dart';

/// Panel kelola daftar soal: tambah/edit/hapus/urutkan, lalu simpan.
/// Dipakai tab Soal layar gabungan phone (FormEditorTabsScreen) dan dual panel
/// tablet/desktop (FormEditorScreen). Tanpa formId = draf lokal penuh
/// (tidak menyentuh server); formId yang datang belakangan (dual form
/// baru seusai simpan pengaturan) diadopsi tanpa reload agar draf lokal
/// tidak tertimpa. Navigasi diserahkan ke parent via [onSaved].
class QuestionsPanel extends StatefulWidget {
  final int? formId;

  /// True = tampil tanpa AppBar sendiri (header di dalam panel) untuk dual.
  final bool embedded;

  /// False = padding list tetap (dipakai kolom dual agar centerPad berbasis
  /// lebar jendela tidak menjepit konten setengah kolom).
  final bool centerContent;

  /// True = soal dikunci (form sudah memiliki respons): daftar hanya tampil,
  /// tambah/ubah/hapus/susun-ulang/impor dinonaktifkan. Pengaturan form
  /// tetap dapat diubah di tab Pengaturan.
  final bool questionsLocked;

  /// Dipanggil SETELAH simpan sukses (menggantikan pop internal).
  final Future<void> Function(int formId)? onSaved;

  const QuestionsPanel({
    super.key,
    required this.formId,
    this.embedded = false,
    this.centerContent = true,
    this.questionsLocked = false,
    this.onSaved,
  });

  @override
  State<QuestionsPanel> createState() => QuestionsPanelState();
}

class QuestionsPanelState extends State<QuestionsPanel>
    with QuestionImportMixin {
  final List<QuestionDraft> _questions = [];
  List<QuestionDraft> _baseline = [];
  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  bool _importing = false;
  double? _progress;

  /// True setelah daftar soal berhasil dimuat dari server minimal sekali.
  /// Dipakai pengaman simpan: draf kosong yang belum pernah dimuat (mis.
  /// gagal koneksi) tidak boleh memicu deleteAllQuestions di server.
  bool _hasLoadedServer = false;

  /// formId efektif: mulai dari widget, diadopsi belakangan bila awalnya
  /// null (dual form baru). Tidak pernah me-reload saat adopsi.
  int? _formId;

  /// True = overlay AFA (AI Form Agent) menutupi panel ini.
  bool _aiOpen = false;

  bool get isSaving => _saving;

  /// API publik untuk header Edit Form (tombol Simpan global + menu aksi
  /// soal tinggal di AppBar layar editor, bukan di header panel ini).
  bool get isBusy => _saving || _importing;
  bool get isQuestionsEmpty => _questions.isEmpty;
  bool get canEditQuestions => !widget.questionsLocked;
  int? get currentFormId => _formId;

  /// True saat daftar soal masih dimuat dari server — parent wajib
  /// menahan tombol Simpan global selama ini (draf kosong sementara bisa
  /// menghapus seluruh soal bila dipaksakan simpan).
  bool get isLoading => _loading;

  /// Validasi draf soal tanpa efek samping (dipakai parent sebelum
  /// menyimpan pengaturan, agar keduanya gagal/berhasil bersamaan).
  String? validateNow() {
    if (widget.questionsLocked) return null;
    return validateQuestionsList(_questions, allowEmpty: true);
  }

  /// Dipanggil layar editor setelah AFA mengubah draf dari luar panel
  /// (mis. dari tab Pengaturan) agar daftar soal langsung rebuild.
  void notifyDraftChanged() {
    if (mounted) setState(() {});
  }

  /// Sorot kartu soal yang baru dikerjakan AFA (border hijau berputar) +
  /// auto-scroll ke kartu pertama. Dipanggil panel AFA setiap satu aksi
  /// diterapkan (mode staggered) — langsung bila overlay milik panel ini,
  /// diteruskan layar editor bila overlay milik layar. Highlight padam
  /// sendiri ±6 detik.
  Set<int> _aiHighlight = {};
  Timer? _aiHighlightTimer;
  final Map<int, GlobalKey> _aiCardKeys = {};

  GlobalKey _aiCardKey(int i) =>
      _aiCardKeys.putIfAbsent(i, () => GlobalKey());

  void flashAiTouched(List<int> indexes) {
    if (!mounted || indexes.isEmpty) return;
    _aiHighlightTimer?.cancel();
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

  /// Ada perubahan vs baseline (dipakai guard keluar gabungan).
  /// Selalu false saat soal dikunci (tidak ada perubahan yang mungkin).
  bool get hasChanges => !widget.questionsLocked && _hasChanges;

  // Anchor tur panduan kelola soal.
  final _addKey = GlobalKey();
  final _aiKey = GlobalKey();
  final _saveKey = GlobalKey();
  OverlayEntry? _tourOverlay;
  bool _tourAutoChecked = false;

  bool get _hasChanges {
    if (_questions.length != _baseline.length) return true;
    for (var i = 0; i < _questions.length; i++) {
      if (!_questions[i].sameAs(_baseline[i])) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _formId = widget.formId;
    if (_formId != null) {
      _loadQuestions();
    } else {
      // Draf lokal penuh (form baru sebelum pengaturan disimpan): tidak ada
      // yang dimuat, matikan loading agar empty state langsung tampil.
      _loading = false;
      // Tawarkan tur mini sekali per akun.
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoTour());
    }
  }

  @override
  void didUpdateWidget(covariant QuestionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Adopsi formId yang datang belakangan (dual: pengaturan baru disimpan)
    // TANPA reload â€” draf lokal adalah kebenaran, server belum punya soal.
    if (_formId == null && widget.formId != null) {
      _formId = widget.formId;
    } else if (_formId != null &&
        widget.formId != null &&
        widget.formId != _formId) {
      _formId = widget.formId;
      _loadQuestions();
    }
  }

  @override
  void dispose() {
    _tourOverlay?.remove();
    _tourOverlay = null;
    _aiHighlightTimer?.cancel();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  /// Konfirmasi keluar: simpan / buang draf / batal (dipakai guard parent).
  Future<bool> confirmExit() async {
    // Overlay AFA terbuka: Back menutup overlay dulu, bukan keluar layar.
    if (_aiOpen) {
      setState(() => _aiOpen = false);
      return false;
    }
    // Soal dikunci: tidak ada perubahan yang mungkin, langsung izin keluar.
    if (widget.questionsLocked) return true;
    if (_saving) return false;
    if (!_hasChanges) return true;
    final choice = await showExitConfirmDialog(context);
    if (!mounted) return false;
    if (choice == 'discard') return true;
    if (choice == 'save') {
      await _save();
      return false; // _save yang menutup screen.
    }
    return false;
  }

  /// [refresh]=true melewati cache (dipakai swipe-refresh agar edit dari
  /// web/perangkat lain langsung terlihat).
  Future<void> _loadQuestions({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final questions = await FormService.getQuestions(_formId!, refresh: refresh);
      if (!mounted) return;
      setState(() {
        _questions
          ..clear()
          ..addAll(draftsFromQuestions(questions));
        _baseline = [for (final q in _questions) q.copy()];
        _loadError = null;
        _hasLoadedServer = true;
      });
      _maybeAutoTour();
    } catch (e) {
      if (!mounted) return;
      if (AuthService.isConnectionError(e)) {
        setState(() => _loadError = AuthService.errorMessage(e));
        return;
      }
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Tur mini kelola soal: sekali per akun; Lewati tersedia selama tur.
  Future<void> _maybeAutoTour() async {
    if (_tourAutoChecked || _tourOverlay != null || !mounted) return;
    _tourAutoChecked = true;
    if (await OnboardingFlags.isSeen('questions', AuthService.email)) return;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTour());
  }

  void _showTour() {
    if (_tourOverlay != null || !mounted) return;
    // Mode embedded (tab Soal di layar editor): tombol Simpan + menu aksi
    // sudah pindah ke header Edit Form, jadi langkah tur Simpan dilewati.
    final steps = [
      OnboardingStep(
        anchorKey: _addKey,
        title: 'Tambah Soal',
        description:
            'Ketuk tombol + untuk menambah soal baru: pilihan ganda, checkbox, essay, benar/salah, atau tanggal.',
        icon: Icons.add_circle_outline,
      ),
      // Langkah AI hanya bila panel menampilkan tombol AI sendiri (mode
      // layar tunggal). Mode embedded memakai FAB AI milik layar editor.
      if (!widget.embedded)
        OnboardingStep(
          anchorKey: _aiKey,
          title: 'Buat Soal dengan AI',
          description:
              'Minta AI buatkan soal untuk form ini — sebutkan topik dan jumlah soal yang kamu mau.',
          icon: Icons.auto_awesome_outlined,
        ),
      if (!widget.embedded)
        OnboardingStep(
          anchorKey: _saveKey,
          title: 'Simpan Perubahan',
          description:
              'Jangan lupa Simpan agar susunan dan isi soal tersimpan. Geser kartu soal untuk mengubah urutan.',
          icon: Icons.save_outlined,
        ),
    ];
    _tourOverlay = OverlayEntry(
      builder: (_) => OnboardingTour(
        steps: steps,
        onComplete: () async {
          _tourOverlay?.remove();
          _tourOverlay = null;
          await OnboardingFlags.markSeen('questions', AuthService.email);
        },
      ),
    );
    Overlay.of(context).insert(_tourOverlay!);
  }

  Future<void> _addQuestion() async {
    if (widget.questionsLocked) return;
    final draft = QuestionDraft(1, isRequired: true);
    setState(() => _questions.add(draft));
    await _openEditor(draft);
    // Draf baru yang dibuang (tidak disimpan) dihapus dari daftar.
    if (mounted && draft.question.document.toPlainText().trim().isEmpty) {
      setState(() {
        _questions.remove(draft);
        draft.dispose();
      });
    }
  }

  Future<void> _openEditor(QuestionDraft draft) async {
    if (widget.questionsLocked) return;
    await AppRouter.of(
      context,
    ).push(AppPage.formQuestionEdit, {'formId': _formId, 'draft': draft});
    if (mounted) setState(() {});
  }

  void _moveQuestion(int index, int delta) {
    if (widget.questionsLocked) return;
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _questions.length) return;
    setState(() {
      final q = _questions.removeAt(index);
      _questions.insert(newIndex, q);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (widget.questionsLocked) return;
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final q = _questions.removeAt(oldIndex);
      _questions.insert(newIndex, q);
    });
  }

  Future<void> _clearAllQuestions() async {
    if (widget.questionsLocked) return;
    if (_saving || _importing || _questions.isEmpty) return;
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
    });
  }

  /// Wrapper publik untuk menu di header Edit Form.
  Future<void> clearAllQuestions() => _clearAllQuestions();

  /// Kembalikan draf soal ke data tersimpan terakhir (baseline server).
  /// Dipakai tombol "Reset Draf" di header Edit Form — mencegah konflik
  /// saat form sudah dikerjakan responden: draf lokal yang menyimpang
  /// dibuang dan diganti data server.
  Future<void> resetDraft() async {
    if (widget.questionsLocked) return;
    if (_saving || _importing) return;
    if (!_hasChanges) {
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
      });
      showAuthToast(context, 'Draf soal dikosongkan');
      return;
    }
    await _loadQuestions(refresh: true);
    if (!mounted) return;
    if (_loadError == null) {
      showAuthToast(context, 'Draf soal dikembalikan ke data tersimpan');
    }
  }

  /// Simpan soal ke server (dipakai tombol Simpan + guard keluar).
  /// Navigasi diserahkan ke parent via [QuestionsPanel.onSaved].
  /// No-op saat soal dikunci (tidak ada perubahan yang mungkin).
  ///
  /// [formIdOverride] = id form yang baru dibuat parent (form baru):
  /// state ini belum rebuild sehingga `_formId` internal masih null —
  /// tanpa override, soal diam-diam tidak tersimpan.
  Future<void> save({int? formIdOverride}) {
    if (widget.questionsLocked) return Future.value();
    if (formIdOverride != null && _formId == null) {
      _formId = formIdOverride;
    }
    return _save();
  }

  Future<void> _save() async {
    if (!AppDebouncer.tryAcquire('form:saveQuestions')) return;
    if (_saving) return;
    if (_loading) {
      showAuthToast(context, 'Soal masih dimuat, tunggu sebentar', isError: true);
      return;
    }
    final error = validateQuestionsList(_questions, allowEmpty: true);
    if (error != null) {
      showAuthToast(context, error, isError: true);
      return;
    }
    final formId = _formId;
    if (formId == null) return;
    // Pengaman hapus tak disengaja: daftar belum pernah dimuat dari server
    // (mis. gagal koneksi) + draf kosong bukan berarti user menghapus semua.
    if (_loadError != null) {
      showAuthToast(
        context,
        'Gagal memuat soal — tarik untuk memuat ulang sebelum menyimpan',
        isError: true,
      );
      return;
    }
    if (!_hasLoadedServer && _questions.isEmpty) return;
    setState(() => _saving = true);
    try {
      final res = await persistQuestions(
        formId: formId,
        questions: _questions,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        notify: (msg, {isError = false}) {
          if (mounted) showAuthToast(context, msg, isError: isError);
        },
      );
      if (!mounted) return;
      if (res.abortedOversize) return;
      if (res.deletedAll) {
        showAuthToast(context, "Semua soal berhasil dihapus");
        // Dual-stay: baseline ikut kosong agar guard tidak menagih lagi.
        _baseline = [];
        _hasLoadedServer = true;
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await widget.onSaved?.call(formId);
        return;
      }
      if (res.mediaFailed > 0) {
        // Soal sudah tersimpan; tetap di layar agar media bisa dicoba lagi.
        showAuthToast(
          context,
          'Soal tersimpan, tetapi ${res.mediaFailed} media gagal diupload. Tekan Simpan lagi untuk mencoba ulang.',
          isError: true,
        );
        return;
      }
      // Dual-stay: segarkan baseline agar guard keluar tidak menagih lagi.
      // (Layar tunggal langsung pop sehingga tidak terpengaruh.)
      _baseline = [for (final q in _questions) q.copy()];
      _hasLoadedServer = true;
      showAuthToast(context, "Soal berhasil disimpan");
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await widget.onSaved?.call(formId);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted)
        setState(() {
          _saving = false;
          _progress = null;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appBar = AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape:  Border(bottom: BorderSide(color: cs.outlineVariant)),
        title:  Text(
          'Kelola Soal',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
          ),
        ),
        leading: widget.embedded
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back, color: cs.onSurface),
                onPressed: _saving
                    ? null
                    : () async {
                        final allow = await confirmExit();
                        if (!allow) return;
                        if (!mounted) return;
                        AppRouter.of(context).pop();
                      },
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: LoadingIndicator.button(),
                  )
                : widget.questionsLocked
                    ? const SizedBox.shrink()
                    : FilledButton(
                    key: _saveKey,
                    onPressed: () async {
                      if (!_hasChanges) {
                        await _save();
                        return;
                      }
                      final confirmed = await showSaveConfirmDialog(context);
                      if (confirmed == true) await _save();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
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
                    child: const Text('Simpan'),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MenuAnchor(
              builder: (context, controller, child) => IconButton(
                icon:  Icon(Icons.more_vert, color: cs.onSurface),
                tooltip: 'Opsi',
                onPressed: (_saving || _importing)
                    ? null
                    : () => controller.isOpen ? controller.close() : controller.open(),
              ),
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(
                    Icons.delete_sweep_outlined,
                    size: 18,
                    color: Color(0xFFC0392B),
                  ),
                  onPressed: (_questions.isEmpty || widget.questionsLocked)
                      ? null
                      : _clearAllQuestions,
                  child: const Text(
                    'Hapus Semua Soal',
                    style: TextStyle(color: Color(0xFFC0392B)),
                  ),
                ),
                MenuItemButton(
                  leadingIcon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: LoadingIndicator.inline(),
                        )
                      : const Icon(Icons.upload_file_outlined, size: 20),
                  onPressed: (_formId == null ||
                          _saving ||
                          _importing ||
                          widget.questionsLocked)
                      ? null
                      : importSoal,
                  child: Text(_importing ? 'Mengimpor...' : 'Impor Soal'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.download_outlined, size: 20),
                  onPressed: (_saving || _importing) ? null : downloadTemplate,
                  child: const Text('Unduh Template Import'),
                ),
              ],
            ),
          ),
        ],
      );
    if (widget.embedded) {
      // Di dalam tab Soal layar editor: TIDAK ada header "Kelola Soal"
      // sendiri — hanya item-item soal. Tombol Simpan + menu aksi soal
      // (hapus semua / impor / unduh template / reset draf) tinggal di
      // header Edit Form. FAB tambah soal tetap di area panel.
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: _agentOverlay(_buildBodyContent()),
        floatingActionButton: _fabSlot(cs),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    }
    return Scaffold(
      appBar: appBar,
      body: _agentOverlay(_buildBodyContent()),
      floatingActionButton: _fabSlot(cs),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// FAB selalu ter-mount (dibungkus [Visibility]) agar `_aiKey` tidak
  /// dilepas-pasang: Scaffold menahan FAB lama selama animasi 200 ms,
  /// sehingga memasang ulang GlobalKey yang sama bisa memicu duplikat.
  Widget _fabSlot(ColorScheme cs) {
    return Visibility(
      visible: !_aiOpen,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: _buildQuestionFab(cs),
    );
  }

  /// Overlay **AFA** (AI Form Agent) menutupi panel saat dibuka dari FAB.
  ///
  /// Konten selalu berada di `Stack > Positioned.fill` (bukan langsung
  /// sebagai body) agar membuka/menutup overlay tidak memindahkan subtree
  /// panel (ReorderableListView + scroll position).
  Widget _agentOverlay(Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (_aiOpen)
          Positioned.fill(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AiFormAgentPanel(
                      formId: _formId,
                      settings: null,
                      // Mode kunci: agen tak diberi akses daftar soal.
                      questions: widget.questionsLocked ? null : () => _questions,
                      onChanged: () => setState(() {}),
                      onQuestionsTouched: flashAiTouched,
                      onClose: () => setState(() => _aiOpen = false),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Banner info saat soal dikunci (form sudah memiliki respons).
  Widget _lockedBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
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

  /// Isi body (dipakai layar tunggal & kolom dual).
  Widget _buildBodyContent() {
    if (_loading) {
      // Mirror daftar kartu soal (padding sama seperti daftar asli).
      return SingleChildScrollView(
        padding: widget.centerContent
            ? centerPad(context,
                base: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                wideMaxWidth: 900)
            : const EdgeInsets.fromLTRB(22, 16, 22, 24),
        child: const SkeletonList.questions(itemCount: 4),
      );
    }
    return AbsorbPointer(
              absorbing: _saving || _importing,
              child: AuthBackground(
                plain: true,
                child: SafeArea(
                  child: Column(
                    children: [
                      if (widget.questionsLocked) _lockedBanner(context),
                      if (_saving || _importing)
                        progress.ProgressIndicator.linear(
                          value: _progress,
                          semanticsLabel: _saving ? 'Menyimpan soal' : 'Mengimpor soal',
                        ),
                      Expanded(
                        child: _questions.isEmpty
                            ? SingleChildScrollView(
                                padding: widget.centerContent
                                    ? centerPad(context, base: const EdgeInsets.fromLTRB(22, 12, 22, 24), wideMaxWidth: 900)
                                    : const EdgeInsets.fromLTRB(22, 12, 22, 24),
                                child: _loadError != null
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          ConnectionErrorView(
                                            message: _loadError!,
                                            onRetry: () =>
                                                _loadQuestions(refresh: true),
                                            bare: true,
                                          ),
                                          const SizedBox(height: 80),
                                        ],
                                      )
                                    : const Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    QuestionsEmptyState(),
                                    SizedBox(height: 80),
                                  ],
                                ),
                              )
                            : Stack(
                                children: [
                                  AppRefreshIndicator(
                                    onRefresh: () => _loadQuestions(refresh: true),
                                    indicatorColor: Theme.of(context).colorScheme.primary,
                                    child: ReorderableListView.builder(
                                    padding: widget.centerContent
                                        ? centerPad(context, base: const EdgeInsets.fromLTRB(22, 16, 22, 96), wideMaxWidth: 900)
                                        : const EdgeInsets.fromLTRB(22, 16, 22, 96),
                                    itemCount: _questions.length,
                                    onReorder: _onReorder,
                                    buildDefaultDragHandles: false,
                                    proxyDecorator: (child, index, animation) =>
                                        Transform.scale(
                                          scale: 0.98,
                                          child: Opacity(
                                            opacity: 0.9,
                                            child: Material(
                                              color: Colors.transparent,
                                              elevation: 0,
                                              child: child,
                                            ),
                                          ),
                                        ),
                                    itemBuilder: (context, i) {
                                      final card = Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: AiHighlightBorder(
                                          key: _aiCardKey(i),
                                          active: _aiHighlight.contains(i),
                                          child: QuestionListCard(
                                          index: i,
                                          totalCount: _questions.length,
                                          question: _questions[i],
                                          readOnly: widget.questionsLocked,
                                          onEdit: () => _openEditor(_questions[i]),
                                          onMoveUp: () => _moveQuestion(i, -1),
                                          onMoveDown: () => _moveQuestion(i, 1),
                                          onDelete: () => setState(() {
                                            _questions[i].dispose();
                                            _questions.removeAt(i);
                                          }),
                                          ),
                                        ),
                                      );
                                      // Mode kunci: tanpa gagang drag (susun
                                      // ulang nonaktif, onReorder juga guard).
                                      if (widget.questionsLocked) return card;
                                      return ReorderableDelayedDragStartListener(
                                        key: ValueKey(_questions[i]),
                                        index: i,
                                        child: card,
                                      );
                                    },
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
  }

  /// FAB kelola soal â€” satu definisi untuk semua layout.
  /// Phone (<600): shortcut AI kecil + lingkaran 68px margin L1=16 (identik).
  /// Tablet/desktop: tombol tambah menjadi Extended FAB M3 (tinggi & ikon
  /// disamakan 68px/32, plus label "Tambah Soal") dengan margin kanan ==
  /// bawah berlevel (tablet L1â€“L2, desktop L2â€“L5 mengikuti ukuran window).
  Widget _buildQuestionFab(ColorScheme cs) {
    final disabled = _saving || _importing || widget.questionsLocked;
    final aiFab = buildAiFab(
      key: _aiKey,
      heroTag: 'aiChatForForm',
      onPressed: _formId == null ? null : () => setState(() => _aiOpen = true),
      backgroundColor: cs.surface,
      foregroundColor: cs.primary,
      tooltip: 'Tanya AFA tentang form ini',
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
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Shortcut AI chat: buka chat dengan form ini otomatis di-mention.
        // Mode embedded (tab Soal layar editor phone) tidak menampilkan
        // tombol AI sendiri — layar editor sudah punya FAB AI; dua tombol
        // AI di posisi yang sama terlihat duplikat.
        if (!widget.embedded) aiFab,
        if (!widget.embedded) const SizedBox(height: 12),
        addFab,
      ],
    );
    if (!isTablet(context)) return column;
    return Padding(
      padding: fabPad(context),
      child: column,
    );
  }
}

/// Tombol impor soal dari file â€” sejajar dengan tombol tambah pertanyaan.
// class _ImportSoalButton extends StatelessWidget {
//   final bool importing;
//   final bool disabled;
//   final VoidCallback onPressed;

//   const _ImportSoalButton({
//     required this.importing,
//     required this.disabled,
//     required this.onPressed,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final enabled = !importing && !disabled;
//     return ElevatedButton.icon(
//       onPressed: enabled ? onPressed : null,
//       icon: importing
//           ? const SizedBox(
//               width: 18,
//               height: 18,
//               child: AppLoadingIndicator.inline(),
//             )
//           : const Icon(Icons.upload_file_outlined, size: 20),
//       label: Text(
//         importing ? "Mengimpor..." : "Impor Soal",
//         maxLines: 1,
//         overflow: TextOverflow.ellipsis,
//         style: TextStyle(
//           fontWeight: FontWeight.bold,
//           fontFamily: kFontBold,
//         ),
//       ),
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Theme.of(context).colorScheme.surface,
//         disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
//         side: BorderSide(
//           color: enabled ? kAuthPrimary : kAuthPrimary.withValues(alpha: 0.4),
//         ),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//         padding: const EdgeInsets.symmetric(vertical: 14),
//         foregroundColor: Theme.of(context).colorScheme.primary,
//       ),
//     );
//   }
// }
