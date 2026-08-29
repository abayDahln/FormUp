import 'package:flutter/material.dart';
import 'package:form_up/core/utils/action_debouncer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form/controllers/form_maker_controller.dart';
import 'package:form_up/features/form/widgets/form_confirm_dialogs.dart';
import 'package:form_up/features/form/widgets/form_maker_header_card.dart';
import 'package:form_up/features/form/widgets/form_maker_settings_card.dart';
import 'package:form_up/features/form/widgets/question_image_source_sheet.dart';

/// Edit informasi & pengaturan form (judul, deskripsi, banner, setting).
class FormMakerScreen extends StatefulWidget {
  final int? formId;

  const FormMakerScreen({super.key, this.formId});

  @override
  State<FormMakerScreen> createState() => _FormMakerScreenState();
}

class _FormMakerScreenState extends State<FormMakerScreen> {
  final FormMakerController _form = FormMakerController();
  AppRouterDelegate? _router;
  bool _loading = false;
  bool _saving = false;
  double? _progress;

  bool get _isEdit => widget.formId != null;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _titleFocusNode = FocusNode();
  final GlobalKey _titleFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadForm();
    } else {
      _form.baseline = _form.snapshot();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= AppRouter.of(context);
    _router!.pushBackGuard(_confirmExit);
  }

  @override
  void dispose() {
    _router?.popBackGuard();
    _scrollController.dispose();
    _titleFocusNode.dispose();
    _form.dispose();
    super.dispose();
  }

  Future<void> _loadForm() async {
    setState(() => _loading = true);
    try {
      final form = await FormService.getForm(widget.formId!);
      if (!mounted) return;
      setState(() => _form.applyForm(form));
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Konfirmasi keluar: simpan / buang draf / batal (hanya jika ada perubahan).
  Future<bool> _confirmExit() async {
    if (!_form.hasChanges) return true;
    final choice = await showFormExitConfirmDialog(context);
    if (!mounted) return false;
    if (choice == 'discard') return true;
    if (choice == 'save') {
      await _save();
      return false; // _save yang menutup screen.
    }
    return false;
  }

  Future<void> _save() async {
    if (!AppDebouncer.tryAcquire('form:saveMaker')) return;
    if (_saving) return;
    final title = _form.titleController.text.trim();
    if (title.isEmpty) {
      showAuthToast(context, "Judul form wajib diisi", isError: true);
      // Auto-scroll + fokus ke field judul yang masih kosong
      final ctx = _titleFieldKey.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.2,
        );
        _titleFocusNode.requestFocus();
      }
      return;
    }
    final newBanner = _form.newBanner;
    if (newBanner != null && exceedsUploadLimit(newBanner)) {
      showAuthToast(context, "Banner maksimal 10 MB", isError: true);
      return;
    }

    final settingsPayload = _form.buildSettingsPayload();

    setState(() => _saving = true);
    void setProgress(double p) {
      if (mounted) setState(() => _progress = p);
    }

    try {
      final customLink = sanitizeFormLink(_form.customLinkController.text);
      final int formId;
      if (_isEdit) {
        formId = widget.formId!;
        await FormService.updateForm(
          formId,
          title: _form.titleController.text.trim(),
          description: encodeRichText(_form.descController),
          formLink: customLink.isEmpty ? null : customLink,
        );
      } else {
        formId = await FormService.createForm(
          title: _form.titleController.text.trim(),
          description: encodeRichText(_form.descController),
        );
        if (customLink.isNotEmpty) {
          await FormService.updateForm(formId, formLink: customLink);
        }
      }
      setProgress(0.4);
      await FormService.updateSettings(formId, settingsPayload);
      setProgress(0.7);

      if (_form.newBanner != null) {
        await FormService.uploadBanner(formId, _form.newBanner!, 'banner.jpg');
      } else if (_form.bannerCleared && _isEdit) {
        await FormService.updateForm(formId, bannerImage: '');
      }
      setProgress(1.0);

      if (!mounted) return;
      // Beri tahu layar daftar form/beranda agar auto-refresh.
      formsVersion.value++;
      if (_isEdit) {
        AppRouter.of(context).pop(formId);
        showAuthToast(
          context,
          "Form berhasil diperbarui",
        );
      } else {
        // Form baru: lanjut kelola soal.
        await AppRouter.of(context).push(AppPage.formQuestions, {
          'formId': formId,
          'isNew': true,
        });
        if (!mounted) return;
        AppRouter.of(context).pop(formId);
        showAuthToast(context, "Form berhasil dibuat");
      }
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() {
        _saving = false;
        _progress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xCCBDC9C8)),
        ),
        title: Text(
          _isEdit ? "Edit Form" : "Buat Form",
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () async {
            final allow = await _confirmExit();
            if (!allow) return;
            if (!mounted) return;
            _router!.pop();
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
              absorbing: _saving,
              child: Stack(
                children: [
                AuthBackground(plain: true,
                  child: SafeArea(
                    child: ValueListenableBuilder<ActiveRichEditor?>(
                      valueListenable: activeRichEditor,
                      builder: (context, active, _) {
                        final toolbarVisible = active != null;
                         return SingleChildScrollView(
                           controller: _scrollController,
                           padding: EdgeInsets.fromLTRB(
                             22,
                             4,
                             22,
                             toolbarVisible ? 110 : 24,
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.stretch,
                             children: [
                               FormMakerHeaderCard(
                                 titleController: _form.titleController,
                                 descController: _form.descController,
                                 bannerImage: _form.bannerImage,
                                 newBanner: _form.newBanner,
                                 onPickBanner: _pickBanner,
                                 onRemoveBanner: () => setState(() {
                                   _form.newBanner = null;
                                   _form.bannerImage = null;
                                   _form.bannerCleared = true;
                                 }),
                                 titleFocusNode: _titleFocusNode,
                                 titleFieldKey: _titleFieldKey,
                               ),
                              const SizedBox(height: 16),
                              FormMakerSettingsCard(
                                controller: _form,
                                onChanged: () => setState(() {}),
                                onPickOpenTime: _pickOpenTime,
                                onPickCloseTime: _pickCloseTime,
                              ),
                              const SizedBox(height: 24),
                              AuthPrimaryButton(
                                label: _saving
                                    ? "Menyimpan..."
                                    : (_isEdit ? "Simpan Form" : "Simpan & Kelola Soal"),
                                loading: _saving,
                                progress: _progress,
                                onPressed: _save,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const FloatingRichToolbar(),
              ],
            ),
          ),
    );
  }

  Future<void> _pickOpenTime() async {
    final picked = await _pickDateTime(_form.openFormTime);
    if (picked != null) setState(() => _form.openFormTime = picked);
  }

  Future<void> _pickCloseTime() async {
    final picked = await _pickDateTime(_form.closeFormTime);
    if (picked != null) setState(() => _form.closeFormTime = picked);
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return null;
    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickBanner() async {
    final source = await showQuestionImageSourceSheet(context);
    if (source == null || !mounted) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (exceedsUploadLimit(bytes)) {
        showAuthToast(context, "Banner maksimal 10 MB", isError: true);
        return;
      }
      setState(() => _form.newBanner = bytes);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }
}
