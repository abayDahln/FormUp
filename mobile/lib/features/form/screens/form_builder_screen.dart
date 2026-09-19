import 'package:flutter/material.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/utils/action_debouncer.dart';
import 'package:form_up/core/widgets/adaptive_fab.dart';
import 'package:form_up/core/widgets/app_toast.dart' hide showAuthToast;
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/ai_chat_icon.dart';
import 'package:form_up/core/widgets/loading_indicator.dart';
import 'package:form_up/core/widgets/progress_indicator.dart' as progress;
import 'package:form_up/core/widgets/responsive.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/features/form/controllers/question_validation.dart';
import 'package:form_up/features/form/controllers/questions_persist.dart';
import 'package:form_up/features/form/widgets/form_settings_panel.dart';
import 'package:form_up/features/form/widgets/question_accordion_card.dart';
import 'package:form_up/features/form/widgets/question_import_mixin.dart';

/// Screen builder form all-in-one untuk tablet/desktop (pengganti dual
/// panel): SATU screen berisi kartu pengaturan form + daftar soal berbentuk
/// accordion (klik kartu → seluruh pengaturan soal terbuka di kartu itu).
/// Tombol Simpan hanya satu, di pojok kanan header — menyimpan keseluruhan
/// form (pengaturan → menciptakan formId bila form baru → lalu soal).
class FormBuilderScreen extends StatefulWidget {
  /// null = form baru.
  final int? formId;

  const FormBuilderScreen({super.key, this.formId});

  @override
  State<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends State<FormBuilderScreen>
    with QuestionImportMixin {
  final GlobalKey<FormSettingsPanelState> _settingsKey =
      GlobalKey<FormSettingsPanelState>();
  final GlobalKey _addKey = GlobalKey();
  AppRouterDelegate? _router;

  final List<QuestionDraft> _questions = [];
  List<QuestionDraft> _baseline = [];
  bool _loadingQuestions = false;
  bool _savingQuestions = false;
  bool _importing = false;
  double? _progress;

  /// formId efektif — terisi setelah simpan pertama (form baru).
  int? _formId;

  /// Indeks kartu soal yang terbuka (accordion single-open).
  int? _openIndex;

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
    setState(() => _loadingQuestions = true);
    try {
      final questions =
          await FormService.getQuestions(_formId!, refresh: false);
      if (!mounted) return;
      setState(() {
        _questions
          ..clear()
          ..addAll(draftsFromQuestions(questions));
        _baseline = [for (final q in _questions) q.copy()];
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  /// Guard keluar gabungan: bila pengaturan dan/atau soal kotor → tawarkan
  /// simpan semua, buang, atau batal.
  Future<bool> _guard() async {
    final s = _settingsKey.currentState;
    if (s == null) return true;
    if (s.isSaving || _savingQuestions) return false;
    final dirtySettings = s.hasChanges;
    final dirtyQuestions = _hasQuestionChanges;
    if (!dirtySettings && !dirtyQuestions) return true;
    if (!mounted) return false;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => ResponsiveDialog(
        child: AlertDialog(
          title: const Text('Simpan perubahan?',
              style: TextStyle(fontFamily: kFontBold)),
          content: const Text(
              'Ada perubahan pengaturan dan/atau soal yang belum tersimpan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('Buang',
                  style: TextStyle(color: Color(0xFFC0392B))),
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
    final needQuestions =
        _hasQuestionChanges || (created && _questions.isNotEmpty);

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
        if (result.abortedOversize) return; // soal belum selesai — jangan baseline.
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
    final draft = QuestionDraft(1, isRequired: true);
    setState(() {
      _questions.add(draft);
      _openIndex = _questions.length - 1;
    });
  }

  void _moveQuestion(int index, int delta) {
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

  Widget _buildFab(ColorScheme cs) {
    final disabled = _savingQuestions;
    final aiFab = FloatingActionButton.small(
      heroTag: 'aiChatForFormBuilder',
      onPressed: _formId == null
          ? null
          : () => _router!.push(AppPage.aiChat, {'formId': _formId}),
      backgroundColor: cs.surface,
      foregroundColor: cs.primary,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tooltip: 'Tanya AI tentang form ini',
      child: AiChatIcon(size: 18, color: cs.primary, filled: true),
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
    return Padding(
      padding: fabPad(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          aiFab,
          const SizedBox(height: 12),
          addFab,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final busy = _savingQuestions;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
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
            padding: const EdgeInsets.only(right: 16),
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
        ],
      ),
      body: _buildBody(cs),
      floatingActionButton: _buildFab(cs),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                final twoColumn = isExpanded(context);
                return SingleChildScrollView(
                  padding: centerPad(
                    context,
                    base: EdgeInsets.fromLTRB(
                      22,
                      16,
                      22,
                      toolbarVisible ? 110 : 24,
                    ),
                    // Full width di window sempit (~840-1400); margin sisi
                    // hanya muncul di window ≥1400 (centerPad memakai
                    // wideMaxWidth hanya saat w ≥ kWideBreakpoint).
                    maxWidth: twoColumn ? 1400 : 960,
                    wideMaxWidth: twoColumn ? 1400 : 960,
                  ),
                  child: twoColumn
                      ? _twoColumnContent(cs)
                      : _stackedContent(cs),
                );
              },
            ),
          ),
        ),
        const FloatingRichToolbar(),
      ],
    );
  }

  /// Daftar kartu accordion soal + state loading/empty (dipakai dua layout).
  List<Widget> _questionItems(ColorScheme cs) {
    if (_loadingQuestions) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: LoadingIndicator.circular()),
        ),
      ];
    }
    if (_questions.isEmpty) {
      return [_emptyQuestionsCard(cs)];
    }
    return [
      for (var i = 0; i < _questions.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
          ),
        ),
    ];
  }

  /// Layout lebar: dua kartu berdampingan — kiri pengaturan form,
  /// kanan daftar soal.
  Widget _twoColumnContent(ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KIRI: kartu pengaturan form (tanpa scroll & tombol simpan sendiri
        // — Simpan global di header screen).
        Expanded(
          flex: 5,
          child: FormSettingsPanel(
            key: _settingsKey,
            formId: _formId,
            scrollable: false,
            showSaveButton: false,
            centerContent: false,
          ),
        ),
        const SizedBox(width: 20),
        // KANAN: kartu daftar soal (accordion).
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _questionsSectionHeader(cs),
              const SizedBox(height: 12),
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
        _questionsSectionHeader(cs),
        const SizedBox(height: 12),
        ..._questionItems(cs),
      ],
    );
  }

  Widget _questionsSectionHeader(ColorScheme cs) {
    return Row(
      children: [
        Text(
          _questions.isEmpty ? 'Soal' : 'Soal (${_questions.length})',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        MenuAnchor(
          builder: (context, controller, child) => IconButton(
            icon: Icon(Icons.more_vert, color: cs.onSurface),
            tooltip: 'Opsi soal',
            onPressed: (_savingQuestions || _importing)
                ? null
                : () =>
                    controller.isOpen ? controller.close() : controller.open(),
          ),
          menuChildren: [
            MenuItemButton(
              leadingIcon: const Icon(
                Icons.delete_sweep_outlined,
                size: 18,
                color: Color(0xFFC0392B),
              ),
              onPressed: _questions.isEmpty ? null : _clearAllQuestions,
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
              onPressed: (_formId == null || _savingQuestions || _importing)
                  ? null
                  : importSoal,
              child: Text(_importing ? 'Mengimpor...' : 'Impor Soal'),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.download_outlined, size: 20),
              onPressed:
                  (_savingQuestions || _importing) ? null : downloadTemplate,
              child: const Text('Unduh Template Import'),
            ),
          ],
        ),
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
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}