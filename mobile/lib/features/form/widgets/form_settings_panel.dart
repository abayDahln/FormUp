import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/loading_indicator.dart';
import 'package:form_up/core/widgets/progress_indicator.dart' as progress;
import 'package:form_up/core/utils/action_debouncer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/features/form/controllers/form_maker_controller.dart';
import 'package:form_up/features/form/widgets/form_confirm_dialogs.dart';
import 'package:form_up/features/form/widgets/form_maker_header_card.dart';
import 'package:form_up/features/form/widgets/question_image_source_sheet.dart';

/// Panel pengaturan form (judul, deskripsi, banner, setting) — dipakai ulang
/// oleh layar tunggal phone (FormMakerScreen) dan dual panel tablet/desktop
/// (FormEditorScreen). Draf baru 100% lokal (controller) sampai [save]
/// dipanggil; navigasi diserahkan ke parent via [onSaved].
class FormSettingsPanel extends StatefulWidget {
  /// null = form baru (draf lokal).
  final int? formId;

  /// Dipanggil SETELAH penyimpanan sukses (menggantikan navigasi internal).
  final Future<void> Function(int formId)? onSaved;

  /// False = padding tetap (dipakai kolom dual agar centerPad berbasis
  /// lebar jendela tidak menjepit konten setengah kolom).
  final bool centerContent;

  /// False = sembunyikan tombol simpan internal (FormBuilder punya
  /// satu tombol Simpan global di header).
  final bool showSaveButton;

  /// False = render konten kartu saja TANPA scroll sendiri — dipakai
  /// di dalam scroll view screen builder (kartu settings + accordion soal).
  final bool scrollable;

  const FormSettingsPanel({
    super.key,
    this.formId,
    this.onSaved,
    this.centerContent = true,
    this.showSaveButton = true,
    this.scrollable = true,
  });

  @override
  State<FormSettingsPanel> createState() => FormSettingsPanelState();
}

class FormSettingsPanelState extends State<FormSettingsPanel> {
  final FormMakerController _form = FormMakerController();
  bool _loading = false;
  bool _saving = false;
  double? _progress;

  bool get _isEdit => widget.formId != null;

  /// Ada perubahan vs baseline (dipakai guard keluar gabungan).
  bool get hasChanges => _form.hasChanges;

  /// Controller pengaturan form — dipakai panel agent AI draf (sidebar
  /// builder) untuk mengubah draf lokal secara langsung.
  FormMakerController get formController => _form;

  bool get isSaving => _saving;

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
  void dispose() {
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

  /// Simpan pengaturan ke server. Return formId bila sukses, null bila
  /// gagal/dibatalkan. Toast + dialog yatim sama seperti alur lama;
  /// navigasi via [FormSettingsPanel.onSaved].
  Future<int?> save() async {
    if (!AppDebouncer.tryAcquire('form:saveMaker')) return null;
    if (_saving) return null;
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
      return null;
    }
    final newBanner = _form.newBanner;
    if (newBanner != null && exceedsUploadLimit(newBanner)) {
      showAuthToast(context, "Banner maksimal 10 MB", isError: true);
      return null;
    }

    final settingsPayload = _form.buildSettingsPayload();

    setState(() => _saving = true);
    void setProgress(double p) {
      if (mounted) setState(() => _progress = p);
    }

    // B5: lacak form baru agar bisa dibersihkan bila langkah lanjutan gagal
    // (tanpa ini retry = duplikat, DB = draf yatim).
    int? createdFormId;
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
        createdFormId = formId;
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

      if (!mounted) return null;
      // Dual-stay: segarkan baseline dari server agar guard keluar tidak
      // menagih lagi (sekaligus meluruskan banner/settings pasca-simpan).
      // Gagal refresh = fallback snapshot lokal (tetap konsisten, hanya
      // banner baru akan di-upload ulang bila Simpan ditekan lagi).
      // _invalidateCaches() di FormService sudah bump formsVersion -> auto-refresh
      try {
        final fresh = await FormService.getForm(formId);
        if (!mounted) return null;
        setState(() => _form.applyForm(fresh));
      } catch (_) {
        if (!mounted) return null;
        _form.baseline = _form.snapshot();
      }
      if (_isEdit) {
        showAuthToast(context, "Form berhasil diperbarui");
      }
      await widget.onSaved?.call(formId);
      return formId;
    } catch (e) {
      if (!mounted) return null;
      // B5: form baru + gagal di settings/banner/link = draf yatim.
      // Tawarkan hapus (dengan konfirmasi) atau lanjutkan nanti.
      final orphanId = (!_isEdit) ? createdFormId : null;
      if (orphanId != null) {
        final choice = await showOrphanFormDialog(context, e);
        if (!mounted) return null;
        if (choice == 'delete') {
          try {
            await FormService.deleteForm(orphanId);
            if (!mounted) return null;
            showAuthToast(context, "Draf kosong dihapus");
          } catch (_) {
            if (!mounted) return null;
            showAuthToast(context, "Draf tersimpan (id $orphanId), lanjutkan nanti", isError: true);
          }
        } else {
          showAuthToast(context, "Draf tersimpan, lanjutkan nanti dari daftar form", isError: true);
        }
      } else {
        showAuthToast(context, AuthService.errorMessage(e), isError: true);
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _progress = null;
        });
      }
    }
  }

  /// Isi konten kartu (header card + tombol simpan bila aktif) — dipakai
  /// mode scrollable maupun embed (FormBuilder).
  List<Widget> _contentChildren(BuildContext context) {
    return [
      FormMakerHeaderCard(
        titleController: _form.titleController,
        descController: _form.descController,
        bannerImage: _form.bannerImage,
        newBanner: _form.newBanner,
        onPickBanner: _pickBanner,
        titleFocusNode: _titleFocusNode,
        titleFieldKey: _titleFieldKey,
        settingsController: _form,
        onSettingsChanged: () => setState(() {}),
        onPickOpenTime: _pickOpenTime,
        onPickCloseTime: _pickCloseTime,
      ),
      const SizedBox(height: 24),
      if (widget.showSaveButton)
        AuthPrimaryButton(
          label: _saving
              ? "Menyimpan..."
              : (_isEdit ? "Simpan Form" : "Simpan & Kelola Soal"),
          loading: _saving,
          progress: _progress,
          onPressed: save,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingOverlay(contained: true);
    final progressLine = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saving)
          progress.ProgressIndicator.linear(
            value: _progress,
            semanticsLabel: 'Menyimpan form',
          ),
      ],
    );
    // Mode embed: konten kartu polos tanpa scroll sendiri (screen builder
    // punya satu scroll view + satu FloatingRichToolbar global).
    if (!widget.scrollable) {
      return AbsorbPointer(
        absorbing: _saving,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...progressLine.children,
            ..._contentChildren(context),
          ],
        ),
      );
    }
    return AbsorbPointer(
      absorbing: _saving,
      child: Column(
        children: [
          if (_saving)
            progress.ProgressIndicator.linear(
              value: _progress,
              semanticsLabel: 'Menyimpan form',
            ),
          Expanded(
            child: Stack(
              children: [
                AuthBackground(
                  plain: true,
                  child: SafeArea(
                    child: ValueListenableBuilder<ActiveRichEditor?>(
                      valueListenable: activeRichEditor,
                      builder: (context, active, _) {
                        final toolbarVisible = active != null;
                        return SingleChildScrollView(
                          controller: _scrollController,
                          padding: widget.centerContent
                              ? centerPad(
                                  context,
                                  base: EdgeInsets.fromLTRB(
                                    22,
                                    16,
                                    22,
                                    toolbarVisible ? 110 : 24,
                                  ),
                                  wideMaxWidth: 960,
                                )
                              : EdgeInsets.fromLTRB(
                                  22,
                                  16,
                                  22,
                                  toolbarVisible ? 110 : 24,
                                ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _contentChildren(context),
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
        ],
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
