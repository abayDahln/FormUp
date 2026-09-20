import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/ai_chat_icon.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form/widgets/ai_form_agent_panel.dart';
import 'package:form_up/features/form/widgets/form_settings_panel.dart';
import 'package:form_up/features/form/widgets/form_confirm_dialogs.dart';

/// Edit informasi & pengaturan form (judul, deskripsi, banner, setting).
/// Phone: layar tunggal (panel pengaturan saja).
/// Tablet/desktop: [FormEditorScreen] dual panel (pengaturan + soal).
class FormMakerScreen extends StatefulWidget {
  final int? formId;

  const FormMakerScreen({super.key, this.formId});

  @override
  State<FormMakerScreen> createState() => _FormMakerScreenState();
}

class _FormMakerScreenState extends State<FormMakerScreen> {
  final GlobalKey<FormSettingsPanelState> _panelKey =
      GlobalKey<FormSettingsPanelState>();
  AppRouterDelegate? _router;

  /// True = overlay AFA (AI Form Agent) menutupi layar pengaturan ini.
  bool _aiOpen = false;

  bool get _isEdit => widget.formId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= AppRouter.of(context);
    _router!.pushBackGuard(_confirmExit);
  }

  @override
  void dispose() {
    _router?.popBackGuard();
    super.dispose();
  }

  /// Konfirmasi keluar: simpan / buang draf / batal (hanya jika ada perubahan).
  Future<bool> _confirmExit() async {
    // Overlay AFA terbuka: Back menutup overlay dulu, bukan keluar layar.
    if (_aiOpen) {
      setState(() => _aiOpen = false);
      return false;
    }
    final panel = _panelKey.currentState;
    if (panel == null || !panel.hasChanges) return true;
    final choice = await showFormExitConfirmDialog(context);
    if (!mounted) return false;
    if (choice == 'discard') return true;
    if (choice == 'save') {
      await panel.save();
      return false; // save yang menutup screen via onSaved.
    }
    return false;
  }

  /// Navigasi pasca-simpan (replika alur lama): form baru lanjut kelola
  /// soal, edit langsung kembali.
  Future<void> _onSaved(int formId) async {
    if (!mounted) return;
    if (_isEdit) {
      AppRouter.of(context).pop(formId);
    } else {
      // Form baru: lanjut kelola soal.
      await AppRouter.of(
        context,
      ).push(AppPage.formQuestions, {'formId': formId});
      if (!mounted) return;
      AppRouter.of(context).pop(formId);
      showAuthToast(context, "Form berhasil dibuat");
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: cs.outlineVariant)),
        title: Text(
          _isEdit ? "Edit Form" : "Buat Form",
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
            final allow = await _confirmExit();
            if (!allow) return;
            if (!mounted) return;
            _router!.pop();
          },
        ),
      ),
      body: _agentOverlay(
        FormSettingsPanel(
          key: _panelKey,
          formId: widget.formId,
          onSaved: _onSaved,
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
        heroTag: 'aiFormAgentMaker',
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

  /// Overlay **AFA** (AI Form Agent): bantu menyusun judul & deskripsi form
  /// langsung dari layar pengaturan (daftar soal ada di layar lain).
  ///
  /// Konten selalu berada di `Stack > Positioned.fill` (bukan langsung
  /// sebagai body) agar membuka/menutup overlay tidak memindahkan
  /// [FormSettingsPanel] yang memegang GlobalKey + fokus editor.
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
                        formId: widget.formId,
                        settings: () => _panelKey.currentState?.formController,
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
