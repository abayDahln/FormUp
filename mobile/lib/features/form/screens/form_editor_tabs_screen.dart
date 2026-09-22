import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/ai_chat_icon.dart';
import 'package:form_up/core/widgets/loading_indicator.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form/widgets/ai_form_agent_panel.dart';
import 'package:form_up/features/form/widgets/form_settings_panel.dart';
import 'package:form_up/features/form/widgets/questions_panel.dart';
import 'package:form_up/features/form/widgets/form_confirm_dialogs.dart';

/// Gabungan edit form (phone): SATU screen dengan 2 tab — Pengaturan
/// (FormSettingsPanel) dan Soal (QuestionsPanel).
///
/// Menggantikan FormMakerScreen + FormQuestionsScreen yang terpisah di phone.
/// Tablet/desktop tetap memakai FormBuilderScreen all-in-one (diatur router).
class FormEditorTabsScreen extends StatefulWidget {
  /// null = form baru.
  final int? formId;

  /// 0 = tab Pengaturan, 1 = tab Soal.
  final int initialTab;

  /// True = soal dikunci (form sudah memiliki respons): tab Soal hanya
  /// tampil, tab Pengaturan tetap dapat diubah.
  final bool questionsLocked;

  const FormEditorTabsScreen({
    super.key,
    this.formId,
    this.initialTab = 0,
    this.questionsLocked = false,
  });

  @override
  State<FormEditorTabsScreen> createState() => _FormEditorTabsScreenState();
}

class _FormEditorTabsScreenState extends State<FormEditorTabsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormSettingsPanelState> _settingsKey =
      GlobalKey<FormSettingsPanelState>();
  final GlobalKey<QuestionsPanelState> _questionsKey =
      GlobalKey<QuestionsPanelState>();
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 1),
  );
  AppRouterDelegate? _router;

  /// formId efektif — terisi setelah simpan pertama (form baru).
  int? _formId;

  /// True = overlay AFA (AI Form Agent) menutupi layar ini.
  bool _aiOpen = false;

  /// True saat tombol Simpan global di header sedang menyimpan
  /// pengaturan + soal sekaligus.
  bool _savingAll = false;

  @override
  void initState() {
    super.initState();
    _formId = widget.formId;
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= AppRouter.of(context);
    _router!.pushBackGuard(_guard);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _router?.popBackGuard();
    super.dispose();
  }

  /// Pengaturan tersimpan: form baru mengadopsi formId (panel soal ikut
  /// ter-update via didUpdateWidget tanpa reload) lalu pindah ke tab Soal.
  Future<void> _onSettingsSaved(int formId) async {
    if (!mounted) return;
    if (_formId == null) {
      setState(() => _formId = formId);
      _tabController.animateTo(1);
      showAuthToast(context, 'Form berhasil dibuat, lanjutkan kelola soal');
    }
  }

  /// Satu tombol Simpan di header Edit Form: menyimpan pengaturan form
  /// + soal sekaligus (menciptakan formId bila form baru). Dipakai juga
  /// sebagai pengganti tombol Simpan di tab Pengaturan dan tab Soal yang
  /// sudah dihapus dari panel masing-masing.
  Future<void> _saveAll() async {
    if (_savingAll) return;
    final settings = _settingsKey.currentState;
    final questions = _questionsKey.currentState;
    if (settings == null || settings.isSaving || (questions?.isBusy ?? false)) {
      return;
    }
    setState(() => _savingAll = true);
    try {
      final id = await settings.save();
      if (id == null || !mounted) return;
      if (_formId == null) setState(() => _formId = id);
      // Soal dikunci (form sudah ada yang mengerjakan): hanya pengaturan
      // yang disimpan; draf soal tidak boleh menyentuh server.
      if (!widget.questionsLocked) {
        await questions?.save();
      }
    } finally {
      if (mounted) setState(() => _savingAll = false);
    }
  }

  /// Konfirmasi keluar: simpan / buang draf / batal (bila ada perubahan di
  /// tab mana pun). Pola save mengikuti FormMakerScreen lama.
  Future<bool> _guard() async {
    // Overlay AFA terbuka: Back menutup overlay dulu, bukan keluar layar.
    if (_aiOpen) {
      setState(() => _aiOpen = false);
      return false;
    }
    final settings = _settingsKey.currentState;
    final questions = _questionsKey.currentState;
    final changed = (settings?.hasChanges ?? false) ||
        (questions?.hasChanges ?? false);
    if (!changed) return true;
    final choice = await showFormExitConfirmDialog(context);
    if (!mounted) return false;
    if (choice == 'discard') return true;
    if (choice == 'save') {
      final id = await settings?.save();
      if (!mounted) return false;
      // Form baru: onSettingsSaved sudah adopsi formId + pindah tab Soal.
      await questions?.save();
      if (!mounted) return false;
      if (widget.formId != null) {
        // Mode edit: tutup layar dengan hasil (menggantikan pop onSaved).
        _router!.pop(_formId ?? id);
        return false;
      }
      return false; // form baru: tetap di layar pada tab Soal.
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final questions = _questionsKey.currentState;
    final onSoalTab = _tabController.index == 1;
    final soalBusy = questions?.isBusy ?? false;
    final soalEmpty = questions?.isQuestionsEmpty ?? true;
    final soalLocked = widget.questionsLocked;
    // Menu aksi soal aktif hanya di tab Soal, saat tidak sibuk/dikunci.
    final soalMenuEnabled =
        onSoalTab && !soalBusy && !_savingAll && !soalLocked;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: cs.outlineVariant)),
        title: Text(
          _formId == null ? 'Buat Form' : 'Edit Form',
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
            child: _savingAll
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: LoadingIndicator.button(),
                  )
                : FilledButton(
                    onPressed: _saveAll,
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
          // Menu aksi soal (pindahan dari header "Kelola Soal" yang
          // dihapus): hapus semua, impor, unduh template, reset draf.
          // Hanya relevan di tab Soal.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: cs.onSurface),
              tooltip: 'Opsi soal',
              enabled: onSoalTab && !_savingAll,
              onSelected: (value) async {
                final q = _questionsKey.currentState;
                if (q == null) return;
                switch (value) {
                  case 'clear':
                    await q.clearAllQuestions();
                    break;
                  case 'import':
                    await q.importSoal();
                    break;
                  case 'template':
                    await q.downloadTemplate();
                    break;
                  case 'reset':
                    await q.resetDraft();
                    break;
                }
                if (mounted) setState(() {});
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clear',
                  enabled: soalMenuEnabled && !soalEmpty,
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
                  enabled: onSoalTab && !_savingAll,
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: cs.primary,
          indicatorWeight: 2.5,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Pengaturan'),
            Tab(text: 'Soal'),
          ],
        ),
      ),
      body: _agentOverlay(
        TabBarView(
          controller: _tabController,
          children: [
            // Tombol Simpan di tab Pengaturan dihapus — penyimpanan lewat
            // satu tombol Simpan di header Edit Form (pengaturan + soal).
            FormSettingsPanel(
              key: _settingsKey,
              formId: _formId,
              onSaved: _onSettingsSaved,
              showSaveButton: false,
            ),
            QuestionsPanel(
              key: _questionsKey,
              formId: _formId,
              embedded: true,
              questionsLocked: widget.questionsLocked,
            ),
          ],
        ),
      ),
      floatingActionButton: _fabSlot(cs),
    );
  }

  /// FAB AFA selalu ter-mount (dibungkus [Visibility]) agar tidak
  /// dilepas-pasang — Scaffold menahan FAB lama 200 ms saat berganti,
  /// sehingga memasang ulang GlobalKey yang sama bisa memicu duplikat.
  Widget _fabSlot(ColorScheme cs) {
    return Visibility(
      visible: !_aiOpen,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: FloatingActionButton.small(
        heroTag: 'aiFormAgentTabs',
        onPressed: () => setState(() => _aiOpen = true),
        backgroundColor: cs.surface,
        foregroundColor: cs.primary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tooltip: 'Buka AFA (AI Form Agent)',
        child: AiChatIcon(size: 18, color: cs.primary, filled: true),
      ),
    );
  }

  /// Overlay **AFA** (AI Form Agent) menutupi seluruh TabBarView (bukan
  /// langsung sebagai body) agar membuka/menutup overlay tidak memindahkan
  /// panel yang memegang GlobalKey + fokus editor.
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cs.outlineVariant, width: 1),
                      ),
                      child: AiFormAgentPanel(
                        formId: _formId,
                        settings: () => _settingsKey.currentState?.formController,
                        onChanged: () => setState(() {}),
                        onClose: () => setState(() => _aiOpen = false),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
