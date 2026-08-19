import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'auth_widgets.dart';
import 'rich_editor.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';
import '../app_router.dart';

/// Edit informasi & pengaturan form (judul, deskripsi, banner, setting).
class FormMakerScreen extends StatefulWidget {
  final int? formId;

  const FormMakerScreen({super.key, this.formId});

  @override
  State<FormMakerScreen> createState() => _FormMakerScreenState();
}

/// Snapshot nilai form untuk deteksi perubahan (dipakai konfirmasi keluar).
class _FormSnapshot {
  final String title;
  final String desc;
  final int formTypeId;
  final bool showScore;
  final bool randomizeQuestions;
  final bool oneResponse;
  final bool requiredLogin;
  final DateTime? openFormTime;
  final DateTime? closeFormTime;
  final String timer;
  final String token;
  final String customLink;
  final String? bannerImage;

  const _FormSnapshot({
    required this.title,
    required this.desc,
    required this.formTypeId,
    required this.showScore,
    required this.randomizeQuestions,
    required this.oneResponse,
    required this.requiredLogin,
    required this.openFormTime,
    required this.closeFormTime,
    required this.timer,
    required this.token,
    required this.customLink,
    required this.bannerImage,
  });
}

class _FormMakerScreenState extends State<FormMakerScreen> {
  final QuillController _titleController = richTextController(null);
  final QuillController _descController = richTextController(null);
  final _timerController = TextEditingController();
  final _tokenController = TextEditingController();
  final _customLinkController = TextEditingController();
  AppRouterDelegate? _router;
  bool _loading = false;
  bool _saving = false;
  double? _progress;

  int _formTypeId = 1;
  bool _showScore = false;
  bool _randomizeQuestions = false;
  bool _oneResponse = false;
  bool _requiredLogin = false;
  DateTime? _openFormTime;
  DateTime? _closeFormTime;

  String? _bannerImage;
  Uint8List? _newBanner;
  bool _bannerCleared = false;

  bool _openTimeAlreadySet = false;

  _FormSnapshot? _baseline;

  bool get _isEdit => widget.formId != null;

  String _delta(QuillController c) =>
      jsonEncode(c.document.toDelta().toJson());

  _FormSnapshot _snapshot() => _FormSnapshot(
        title: _delta(_titleController),
        desc: _delta(_descController),
        formTypeId: _formTypeId,
        showScore: _showScore,
        randomizeQuestions: _randomizeQuestions,
        oneResponse: _oneResponse,
        requiredLogin: _requiredLogin,
        openFormTime: _openFormTime,
        closeFormTime: _closeFormTime,
        timer: _timerController.text,
        token: _tokenController.text,
        customLink: _customLinkController.text,
        bannerImage: _newBanner != null
            ? 'new:${_newBanner.hashCode}'
            : _bannerCleared
                ? ''
                : _bannerImage,
      );

  bool get _hasChanges {
    final base = _baseline;
    if (base == null) return false;
    final cur = _snapshot();
    return base.title != cur.title ||
        base.desc != cur.desc ||
        base.formTypeId != cur.formTypeId ||
        base.showScore != cur.showScore ||
        base.randomizeQuestions != cur.randomizeQuestions ||
        base.oneResponse != cur.oneResponse ||
        base.requiredLogin != cur.requiredLogin ||
        base.openFormTime != cur.openFormTime ||
        base.closeFormTime != cur.closeFormTime ||
        base.timer != cur.timer ||
        base.token != cur.token ||
        base.customLink != cur.customLink ||
        base.bannerImage != cur.bannerImage;
  }

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadForm();
    } else {
      _baseline = _snapshot();
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
    _titleController.dispose();
    _descController.dispose();
    _timerController.dispose();
    _tokenController.dispose();
    _customLinkController.dispose();
    super.dispose();
  }

  Future<void> _loadForm() async {
    setState(() => _loading = true);
    try {
      final form = await FormService.getForm(widget.formId!);
      if (!mounted) return;

      final settings = form['settings'] as Map<String, dynamic>?;
      final rawOpen = settings?['openFormTime'] as String?;
      final rawClose = settings?['closeFormTime'] as String?;
      setState(() {
        _titleController.document = richDocument(form['title'] as String?);
        _descController.document = richDocument(form['description'] as String?);
        _bannerImage = form['bannerImage'] as String?;
        _newBanner = null;
        _bannerCleared = false;
        _formTypeId = (settings?['formTypeId'] as int?) ?? 1;
        _showScore = settings?['showScore'] == true;
        _randomizeQuestions = settings?['randomizeQuestions'] == true;
        _oneResponse = settings?['oneResponse'] == true;
        _requiredLogin = settings?['requiredLogin'] == true;
        _openFormTime =
            rawOpen != null ? DateTime.tryParse(rawOpen)?.toLocal() : null;
        _closeFormTime =
            rawClose != null ? DateTime.tryParse(rawClose)?.toLocal() : null;
        _openTimeAlreadySet = _openFormTime != null;
        if (settings?['timerDuration'] is int) {
          _timerController.text = '${settings!['timerDuration']}';
        }
        _customLinkController.text = form['formLink'] as String? ?? '';
        _baseline = _snapshot();
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Konfirmasi keluar: simpan / buang draf / batal (hanya jika ada perubahan).
  Future<bool> _confirmExit() async {
    if (!_hasChanges) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Simpan Perubahan?',
          style: TextStyle(fontFamily: kFontBold),
        ),
        content: const Text(
          'Perubahan form belum disimpan. Simpan atau buang draf?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text(
              'Buang Draf',
              style: TextStyle(color: Color(0xFFC0392B)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text(
              'Simpan',
              style: TextStyle(color: kAuthPrimary),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (choice == 'discard') return true;
    if (choice == 'save') {
      await _save();
      return false; // _save yang menutup screen.
    }
    return false;
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.document.toPlainText().trim();
    if (title.isEmpty) {
      showAuthToast(context, "Judul form wajib diisi", isError: true);
      return;
    }
    if (_newBanner != null && exceedsUploadLimit(_newBanner!)) {
      showAuthToast(context, "Banner maksimal 10 MB", isError: true);
      return;
    }

    final settingsPayload = <String, dynamic>{
      'formTypeId': _formTypeId,
      'showScore': _showScore,
      'randomizeQuestions': _randomizeQuestions,
      'oneResponse': _oneResponse,
      'requiredLogin': _requiredLogin,
      if (_timerController.text.trim().isNotEmpty)
        'timerDuration': int.tryParse(_timerController.text.trim()),
      if (_tokenController.text.trim().isNotEmpty)
        'formToken': _tokenController.text.trim(),
      if (_openFormTime != null && !_openTimeAlreadySet)
        'openFormTime': _openFormTime!.toUtc().toIso8601String(),
      if (_closeFormTime != null)
        'closeFormTime': _closeFormTime!.toUtc().toIso8601String(),
    };

    setState(() => _saving = true);
    void setProgress(double p) {
      if (mounted) setState(() => _progress = p);
    }

    try {
      final customLink = _sanitizeLink(_customLinkController.text);
      final int formId;
      if (_isEdit) {
        formId = widget.formId!;
        await FormService.updateForm(
          formId,
          title: _titleController.document.toPlainText().trim(),
          description: encodeRichText(_descController),
          formLink: customLink.isEmpty ? null : customLink,
        );
      } else {
        formId = await FormService.createForm(
          title: _titleController.document.toPlainText().trim(),
          description: encodeRichText(_descController),
        );
        if (customLink.isNotEmpty) {
          await FormService.updateForm(formId, formLink: customLink);
        }
      }
      setProgress(0.4);
      await FormService.updateSettings(formId, settingsPayload);
      setProgress(0.7);

      if (_newBanner != null) {
        await FormService.uploadBanner(formId, _newBanner!, 'banner.jpg');
      } else if (_bannerCleared && _isEdit) {
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
      backgroundColor: kAuthBg,
      appBar: AppBar(
        backgroundColor: kAuthBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _isEdit ? "Edit Form" : "Buat Form",
          style: const TextStyle(
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
          : Stack(
              children: [
                AuthBackground(
                  child: SafeArea(
                    child: ValueListenableBuilder<ActiveRichEditor?>(
                      valueListenable: activeRichEditor,
                      builder: (context, active, _) {
                        final toolbarVisible = active != null;
                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            4,
                            22,
                            toolbarVisible ? 110 : 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildFormHeader(),
                              const SizedBox(height: 16),
                              _buildSettingsCard(),
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
    );
  }

  Widget _buildFormHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xCCBDC9C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Judul Form",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: kAuthPrimary,
            ),
          ),
          const SizedBox(height: 8),
          RichTextEditor(
            controller: _titleController,
            hint: "Contoh: Survey Kepuasan",
            minHeight: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            "Deskripsi",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: kAuthPrimary,
            ),
          ),
          const SizedBox(height: 8),
          RichTextEditor(
            controller: _descController,
            hint: "Jelaskan tujuan form Anda (opsional)",
            minHeight: 60,
          ),
          const SizedBox(height: 16),
          _buildBannerField(),
        ],
      ),
    );
  }

  Widget _buildBannerField() {
    final hasImage = _newBanner != null || (_bannerImage?.isNotEmpty ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Banner Form",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: kAuthPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 140,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6E7979)),
          ),
          child: hasImage
              ? (_newBanner != null
                    ? Image.memory(
                        _newBanner!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined,
                              size: 32, color: Colors.grey),
                        ),
                      )
                    : Image.network(
                        profileImageUrl(_bannerImage),
                        fit: BoxFit.cover,
                        cacheWidth: 800,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined,
                              size: 32, color: Colors.grey),
                        ),
                      ))
              : const Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 32,
                    color: Colors.grey,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickBanner,
                icon: const Icon(Icons.upload_outlined, size: 18, color: kAuthPrimary),
                label: Text(
                  hasImage ? "Ganti Banner" : "Upload Banner",
                  style: const TextStyle(color: kAuthPrimary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kAuthPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _newBanner = null;
                  _bannerImage = null;
                  _bannerCleared = true;
                }),
                icon: const Icon(Icons.close, size: 18, color: Color(0xFFC0392B)),
                label: const Text(
                  "Hapus",
                  style: TextStyle(color: Color(0xFFC0392B)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFC0392B)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xCCBDC9C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: kAuthPrimary),
              const SizedBox(width: 8),
              const Text(
                "Pengaturan",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _settingsLabel("Tipe Form"),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _formTypeId,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 1, child: Text("Single Page")),
                DropdownMenuItem(value: 2, child: Text("Multi Page")),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _formTypeId = v);
              },
            ),
          ),
          const SizedBox(height: 8),
          _settingsLabel("Link Kustom"),
          TextField(
            controller: _customLinkController,
            decoration: _fieldDecoration(
              "mis. survey-kepuasan (opsional)",
            ),
            onChanged: (v) => _customLinkController.value =
                _customLinkController.value.copyWith(
              text: _sanitizeLink(v),
              selection: TextSelection.collapsed(
                offset: _sanitizeLink(v).length,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _settingsLabel("Batas Waktu"),
          TextField(
            controller: _timerController,
            keyboardType: TextInputType.number,
            decoration: _fieldDecoration(
              "menit (opsional)",
            ),
          ),
          const SizedBox(height: 8),
          _settingsLabel("Token Akses"),
          TextField(
            controller: _tokenController,
            decoration: _fieldDecoration(
              "opsional",
            ),
          ),
          const SizedBox(height: 8),
          _buildDateTimeTile(
            icon: Icons.lock_open_outlined,
            title: "Waktu buka form",
            subtitle: _openTimeAlreadySet
                ? "Sudah diatur, tidak bisa diubah"
                : "Form terbuka otomatis di waktu ini",
            value: _openFormTime,
            enabled: !_openTimeAlreadySet,
            onTap: _openTimeAlreadySet ? null : () => _pickOpenTime(),
          ),
          const SizedBox(height: 8),
          _buildDateTimeTile(
            icon: Icons.lock_outline,
            title: "Waktu tutup form",
            subtitle: "Form berhenti menerima respons",
            value: _closeFormTime,
            enabled: true,
            onTap: () => _pickCloseTime(),
          ),
          const SizedBox(height: 8),
          _buildSwitch(
            "Tampilkan skor",
            "Responden melihat nilai setelah submit",
            _showScore,
            (v) => setState(() => _showScore = v),
          ),
          _buildSwitch(
            "Acak pertanyaan",
            "Urutan pertanyaan diacak",
            _randomizeQuestions,
            (v) => setState(() => _randomizeQuestions = v),
          ),
          _buildSwitch(
            "Satu respons per orang",
            "Batasi tiap orang hanya 1 kali isi",
            _oneResponse,
            (v) => setState(() => _oneResponse = v),
          ),
          _buildSwitch(
            "Wajib login",
            "Responden harus login untuk mengerjakan",
            _requiredLogin,
            (v) => setState(() => _requiredLogin = v),
          ),
        ],
      ),
    );
  }

  Widget _settingsLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          color: kAuthPrimary,
        ),
      ),
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    // Material transparan agar ink splash ListTile tidak tertutup DecoratedBox.
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        value: value,
        activeTrackColor: kAuthPrimary,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDateTimeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required DateTime? value,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? const Color(0xFF6E7979) : const Color(0xFFD8DEDE),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled ? kAuthPrimary : Colors.grey.shade400,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value == null
                        ? (enabled ? subtitle : "Belum diatur")
                        : _formatDateTime(value),
                    style: TextStyle(
                      fontSize: 12,
                      color: value != null
                          ? kAuthPrimary
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey)
            else
              const Icon(
                Icons.lock,
                size: 16,
                color: Colors.grey,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickOpenTime() async {
    final picked = await _pickDateTime(_openFormTime);
    if (picked != null) setState(() => _openFormTime = picked);
  }

  Future<void> _pickCloseTime() async {
    final picked = await _pickDateTime(_closeFormTime);
    if (picked != null) setState(() => _closeFormTime = picked);
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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFBDC9C8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _imageSourceTile(
              icon: Icons.photo_library_outlined,
              label: 'Pilih dari Galeri',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            _imageSourceTile(
              icon: Icons.photo_camera_outlined,
              label: 'Ambil Foto',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
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
      setState(() => _newBanner = bytes);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  Widget _imageSourceTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: kPrimarySoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBDC9C8)),
        ),
        child: Row(
          children: [
            Icon(icon, color: kAuthPrimary, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  String _sanitizeLink(String value) {
    final v = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
    return v.length > 100 ? v.substring(0, 100) : v;
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return "${local.day} ${months[local.month - 1]} ${local.year}, $hh:$mm";
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kAuthText, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF0F4F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kAuthText),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF6E7979)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kAuthPrimary, width: 1.5),
      ),
    );
  }
}
