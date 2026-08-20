import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'auth_widgets.dart';
import 'rich_editor.dart';
import 'question_draft.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';
import '../app_router.dart';

/// Edit satu soal (detail): tipe, teks, opsi, kunci jawaban, media, wajib.
class FormQuestionEditScreen extends StatefulWidget {
  final int? formId;
  final QuestionDraft draft;

  const FormQuestionEditScreen({
    super.key,
    required this.formId,
    required this.draft,
  });

  @override
  State<FormQuestionEditScreen> createState() => _FormQuestionEditScreenState();
}

class _FormQuestionEditScreenState extends State<FormQuestionEditScreen> {
  late final QuestionDraft _working;
  AppRouterDelegate? _router;
  bool _preview = false;
  bool _uploading = false;

  QuestionDraft get q => _working;

  @override
  void initState() {
    super.initState();
    // Edit di salinan; baru ditulis ke draf asli saat "Simpan".
    _working = widget.draft.copy();
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
    _working.dispose();
    super.dispose();
  }

  Future<bool> _confirmExit() async {
    // Tidak ada perubahan → langsung izinkan keluar tanpa dialog.
    if (_working.sameAs(widget.draft)) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Simpan Perubahan?',
          style: TextStyle(fontFamily: kFontBold),
        ),
        content: const Text(
          'Perubahan soal belum disimpan. Simpan atau buang draf?',
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
      if (!_validate()) return false;
      _commit();
      return true;
    }
    return false;
  }

  bool _validate() {
    final questionText = q.question.document.toPlainText().trim();
    if (questionText.isEmpty) {
      showAuthToast(context, "Teks pertanyaan tidak boleh kosong", isError: true);
      return false;
    }
    if (q.hasOptions) {
      if (q.options.isEmpty) {
        showAuthToast(
          context,
          "Tambahkan opsi pada pertanyaan pilihan",
          isError: true,
        );
        return false;
      }
      for (final o in q.options) {
        if (o.text.document.toPlainText().trim().isEmpty) {
          showAuthToast(context, "Teks opsi tidak boleh kosong", isError: true);
          return false;
        }
      }
    }
    return true;
  }

  void _commit() {
    widget.draft.copyFrom(_working);
  }

  Future<void> _save() async {
    if (!_validate()) return;
    if (!_working.sameAs(widget.draft)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Simpan Soal?',
            style: TextStyle(fontFamily: kFontBold),
          ),
          content: const Text('Soal akan disimpan ke draf kelola soal.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Simpan',
                style: TextStyle(color: kAuthPrimary),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _commit();
    AppRouter.of(context).pop();
  }

  Future<void> _pickQuestionImage() async {
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
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (exceedsUploadLimit(bytes)) {
        showAuthToast(context, "Gambar maksimal 10 MB", isError: true);
        return;
      }
      // Soal belum punya id → simpan sebagai draf, upload setelah tersimpan.
      if (q.id == null) {
        setState(() {
          q.pendingImageBytes = bytes;
          q.pendingImageName = 'question.jpg';
          q.questionImage = null;
        });
        return;
      }
      setState(() => _uploading = true);
      try {
        final path = await FormService.uploadQuestionImage(
          widget.formId!,
          q.id!,
          bytes,
          'question.jpg',
        );
        if (!mounted) return;
        setState(() => q.questionImage = path);
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  Future<void> _pickQuestionAudio() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      if (file == null || file.bytes == null) return;
      if (!mounted) return;
      if (exceedsUploadLimit(file.bytes!)) {
        showAuthToast(context, "Audio maksimal 10 MB", isError: true);
        return;
      }
      // Soal belum punya id → simpan sebagai draf, upload setelah tersimpan.
      if (q.id == null) {
        setState(() {
          q.pendingAudioBytes = file.bytes;
          q.pendingAudioName = file.name;
          q.questionAudio = null;
        });
        return;
      }
      setState(() => _uploading = true);
      try {
        final path = await FormService.uploadQuestionAudio(
          widget.formId!,
          q.id!,
          file.bytes!,
          file.name,
        );
        if (!mounted) return;
        setState(() => q.questionAudio = path);
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xCCBDC9C8)),
        ),
        title: const Text(
          'Edit Soal',
          style: TextStyle(
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
      body: Stack(
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
                        _sectionCard(
                          title: 'Soal',
                          icon: Icons.help_outline,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTypeRow(),
                              const SizedBox(height: 12),
                              RichTextEditor(
                                controller: q.question,
                                hint: "Tulis pertanyaan...",
                                minHeight: 70,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    "Pratinjau",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const Spacer(),
                                  Switch(
                                    value: _preview,
                                    activeTrackColor: kAuthPrimary,
                                    onChanged: (v) =>
                                        setState(() => _preview = v),
                                  ),
                                ],
                              ),
                              if (_preview) ...[
                                const SizedBox(height: 8),
                                _buildQuestionPreview(),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _sectionCard(
                          title: 'Jawaban',
                          icon: Icons.rule,
                          child: _buildAnswerSection(),
                        ),
                        const SizedBox(height: 16),
                        _sectionCard(
                          title: 'Media',
                          icon: Icons.attach_file,
                          child: _buildQuestionMedia(),
                        ),
                        const SizedBox(height: 16),
                        _sectionCard(
                          title: 'Pengaturan',
                          icon: Icons.tune,
                          child: Row(
                            children: [
                              const Text(
                                "Wajib dijawab",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: q.isRequired,
                                activeTrackColor: kAuthPrimary,
                                onChanged: (v) =>
                                    setState(() => q.isRequired = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AuthPrimaryButton(
                          label: "Simpan Soal",
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

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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
              Icon(icon, size: 18, color: kAuthPrimary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildAnswerSection() {
    if (q.typeId == 5) return _buildTrueFalseAnswer();
    if (q.typeId == 1) {
      return TextField(
        controller: q.correctAnswer,
        maxLines: null,
        decoration: _fieldDecoration(
          "Kunci jawaban (opsional, untuk kuis)",
        ),
      );
    }
    if (q.hasOptions) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var oi = 0; oi < q.options.length; oi++)
            _buildOptionRow(oi),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => q.options.add(OptionDraft())),
              icon: const Icon(
                Icons.add_circle_outline,
                size: 18,
                color: kAuthPrimary,
              ),
              label: const Text(
                "Tambahkan opsi",
                style: TextStyle(color: kAuthPrimary),
              ),
            ),
          ),
        ],
      );
    }
    return const Text(
      'Jawaban tanggal & waktu diisi responden langsung.',
      style: TextStyle(fontSize: 12, color: Colors.black45),
    );
  }

  Widget _buildTypeRow() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: q.typeId,
        isExpanded: true,
        items: [
          for (final e in questionTypes.entries)
            DropdownMenuItem(
              value: e.key,
              child: Text(
                e.value.$1,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            q.typeId = v;
            if (!q.hasOptions) {
              for (final o in q.options) {
                o.text.dispose();
              }
              q.options.clear();
            }
          });
        },
      ),
    );
  }

  Widget _buildQuestionPreview() {
    final previewText = q.question.document.toPlainText().trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBDC9C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 14, color: kAuthPrimary),
              const SizedBox(width: 4),
              const Text(
                "Pratinjau Soal",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: kAuthPrimary,
                ),
              ),
              const Spacer(),
              Text(
                questionTypes[q.typeId]?.$1 ?? '',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (previewText.isEmpty)
            const Text(
              'Belum ada teks pertanyaan.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black45,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            RichTextView(
              text: encodeRichText(q.question),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          const SizedBox(height: 8),
          if (q.typeId == 2)
            for (final o in q.options)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.radio_button_unchecked,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichTextView(
                        text: encodeRichText(o.text),
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              )
          else if (q.typeId == 3)
            for (final o in q.options)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_box_outline_blank,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichTextView(
                        text: encodeRichText(o.text),
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              )
          else if (q.typeId == 5)
            const Row(
              children: [
                Expanded(child: _PreviewChip('Benar')),
                SizedBox(width: 8),
                Expanded(child: _PreviewChip('Salah')),
              ],
            )
          else if (q.typeId == 4)
            const Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  'Pilih tanggal & waktu',
                  style: TextStyle(fontSize: 13, color: Colors.black45),
                ),
              ],
            )
          else
            Text(
              q.typeId == 1 ? 'Jawaban esai (teks panjang)' : '',
              style: const TextStyle(fontSize: 13, color: Colors.black45),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionMedia() {
    final hasImage = q.questionImage != null || q.pendingImageBytes != null;
    final hasAudio = q.questionAudio != null || q.pendingAudioBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (q.pendingImageBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              q.pendingImageBytes!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 120,
                alignment: Alignment.center,
                color: const Color(0xFFF0F4F4),
                child: const Icon(Icons.broken_image_outlined,
                    size: 32, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ] else if (q.questionImage != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              profileImageUrl(q.questionImage),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: 800,
              errorBuilder: (_, _, _) => Container(
                height: 120,
                alignment: Alignment.center,
                color: const Color(0xFFF0F4F4),
                child: const Icon(Icons.broken_image_outlined,
                    size: 32, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (hasAudio) ...[
          Row(
            children: [
              const Icon(Icons.audio_file, size: 18, color: kAuthPrimary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Audio terlampir',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                onPressed: () => setState(() {
                  q.questionAudio = null;
                  q.pendingAudioBytes = null;
                  q.pendingAudioName = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        if (_uploading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (hasImage)
                TextButton.icon(
                  onPressed: () => setState(() {
                    q.questionImage = null;
                    q.pendingImageBytes = null;
                    q.pendingImageName = null;
                  }),
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFFC0392B)),
                  label: const Text(
                    'Hapus Gambar',
                    style: TextStyle(fontSize: 12, color: Color(0xFFC0392B)),
                  ),
                ),
              if (hasAudio)
                TextButton.icon(
                  onPressed: () => setState(() {
                    q.questionAudio = null;
                    q.pendingAudioBytes = null;
                    q.pendingAudioName = null;
                  }),
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFFC0392B)),
                  label: const Text(
                    'Hapus Audio',
                    style: TextStyle(fontSize: 12, color: Color(0xFFC0392B)),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _pickQuestionImage,
                icon: const Icon(Icons.image_outlined, size: 16, color: kAuthPrimary),
                label: Text(
                  hasImage ? 'Ganti Gambar' : 'Tambah Gambar',
                  style: const TextStyle(fontSize: 12, color: kAuthPrimary),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickQuestionAudio,
                icon: const Icon(Icons.audio_file_outlined, size: 16, color: kAuthPrimary),
                label: Text(
                  hasAudio ? 'Ganti Audio' : 'Tambah Audio',
                  style: const TextStyle(fontSize: 12, color: kAuthPrimary),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTrueFalseAnswer() {
    return Row(
      children: [
        Expanded(
          child: _answerChip(
            "Benar",
            q.correctAnswer.text == 'Benar',
            () => setState(() => q.correctAnswer.text = 'Benar'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _answerChip(
            "Salah",
            q.correctAnswer.text == 'Salah',
            () => setState(() => q.correctAnswer.text = 'Salah'),
          ),
        ),
      ],
    );
  }

  Widget _answerChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kPrimarySoft : const Color(0xFFF0F4F4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? kAuthPrimary : const Color(0xFF6E7979),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: selected ? kAuthPrimary : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow(int oi) {
    final o = q.options[oi];
    final singleSelect = q.typeId == 2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (singleSelect) {
                  for (final opt in q.options) {
                    opt.isCorrect = false;
                  }
                  o.isCorrect = true;
                } else {
                  o.isCorrect = !o.isCorrect;
                }
              });
            },
            child: Icon(
              singleSelect
                  ? (o.isCorrect
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked)
                  : (o.isCorrect
                        ? Icons.check_box
                        : Icons.check_box_outline_blank),
              color: o.isCorrect ? kAuthPrimary : const Color(0xFF6E7979),
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichTextEditor(
              controller: o.text,
              hint: "Opsi ${oi + 1}",
              minHeight: 40,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: () {
              setState(() {
                o.text.dispose();
                q.options.removeAt(oi);
              });
            },
          ),
        ],
      ),
    );
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

class _PreviewChip extends StatelessWidget {
  final String label;

  const _PreviewChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6E7979)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: Colors.black54),
      ),
    );
  }
}