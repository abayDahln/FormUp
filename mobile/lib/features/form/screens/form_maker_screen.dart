import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/router/app_router.dart';
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
      await AppRouter.of(context).push(AppPage.formQuestions, {
        'formId': formId,
      });
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
        shape:  Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
        title: Text(
          _isEdit ? "Edit Form" : "Buat Form",
          style:  TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
          ),
        ),
        leading: IconButton(
          icon:  Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () async {
            final allow = await _confirmExit();
            if (!allow) return;
            if (!mounted) return;
            _router!.pop();
          },
        ),
      ),
      body: FormSettingsPanel(
        key: _panelKey,
        formId: widget.formId,
        onSaved: _onSaved,
      ),
    );
  }
}
