import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:form_up/features/form/widgets/question_answer_section.dart';
import 'package:form_up/features/form/widgets/question_image_source_sheet.dart';
import 'package:form_up/features/form/widgets/question_media_section.dart';
import 'package:form_up/features/form/widgets/question_required_switch.dart';
import 'package:form_up/features/form/widgets/question_text_section.dart';
import 'package:image_picker/image_picker.dart';

/// Kartu soal accordion untuk FormBuilder (tablet/desktop): header ringkas
/// (nomor, preview teks, tipe) yang bisa dibuka — saat terbuka seluruh
/// pengaturan soal (pertanyaan, tipe, jawaban, pengaturan, media) tampil
/// dalam satu kartu. Perubahan langsung menulis ke [draft] (satu tombol
/// Simpan global di screen), jadi tanpa dialog "Simpan Soal" per kartu.
class QuestionAccordionCard extends StatefulWidget {
  final int index;
  final int totalCount;
  final QuestionDraft draft;

  /// True = kartu terbuka (accordion single-open dikelola screen).
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  const QuestionAccordionCard({
    super.key,
    required this.index,
    required this.totalCount,
    required this.draft,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  @override
  State<QuestionAccordionCard> createState() => _QuestionAccordionCardState();
}

class _QuestionAccordionCardState extends State<QuestionAccordionCard> {
  bool _uploading = false;

  /// True = isi section Pengaturan (wajib + media) terbuka. Default tutup
  /// agar kartu soal tidak terlalu panjang ke bawah.
  bool _settingsOpen = false;
  QuestionDraft get q => widget.draft;

  Future<void> _pickQuestionImage() async {
    final source = await showQuestionImageSourceSheet(context);
    if (source == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) {
        if (mounted) setState(() => _uploading = false);
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (exceedsUploadLimit(bytes)) {
        showAuthToast(context, "Gambar maksimal 10 MB", isError: true);
        return;
      }
      setState(() {
        q.pendingImageBytes = bytes;
        q.pendingImageName = 'question.jpg';
        // Nilai final questionImage baru ditetapkan setelah soal disimpan.
        q.questionImage = null;
      });
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickQuestionAudio() async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) return;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (_) {
          bytes = null;
        }
      }
      if (bytes == null) {
        if (!mounted) return;
        showAuthToast(context, "Gagal membaca file audio", isError: true);
        return;
      }
      if (!mounted) return;
      if (exceedsUploadLimit(bytes)) {
        showAuthToast(context, "Audio maksimal 10 MB", isError: true);
        return;
      }
      setState(() {
        q.pendingAudioBytes = bytes;
        q.pendingAudioName = file.name;
        q.questionAudio = null;
      });
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      showAuthToast(
          context, msg.isEmpty ? "Gagal memproses audio" : msg, isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _onTypeChanged(int v) {
    setState(() {
      q.typeId = v;
      if (!q.hasOptions) {
        for (final o in q.options) {
          o.text.dispose();
        }
        q.options.clear();
      }
    });
    widget.onChanged();
  }

  Widget _sectionTitle(IconData icon, String text, ColorScheme cs) => Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: cs.onSurface,
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final plainText = q.question.document.toPlainText().trim();
    final typeLabel = questionTypes[q.typeId]?.$1 ?? '';

    final header = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onToggle,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  "${widget.index + 1}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: cs.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plainText.isEmpty ? 'Belum ada teks pertanyaan.' : plainText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: kFontBold,
                      color: cs.onSurface,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            MenuAnchor(
              builder: (context, controller, child) => IconButton(
                icon:
                    Icon(Icons.more_vert, size: 20, color: cs.onSurfaceVariant),
                tooltip: 'Opsi soal',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
              ),
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(Icons.unfold_more, size: 18),
                  onPressed: widget.onToggle,
                  child: Text(widget.expanded ? 'Tutup' : 'Buka Soal'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: widget.index > 0 ? widget.onMoveUp : null,
                  child: const Text('Pindah ke atas'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: widget.index < widget.totalCount - 1
                      ? widget.onMoveDown
                      : null,
                  child: const Text('Pindah ke bawah'),
                ),
                const Divider(height: 1),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.delete_outline,
                      size: 18, color: Color(0xFFC0392B)),
                  onPressed: widget.onDelete,
                  child: const Text('Hapus',
                      style: TextStyle(color: Color(0xFFC0392B))),
                ),
              ],
            ),
            AnimatedRotation(
              turns: widget.expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(Icons.keyboard_arrow_down,
                  size: 24, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );

    if (!widget.expanded) {
      return Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: header,
      );
    }
    return _buildExpanded(context, cs, header);
  }

  Widget _buildExpanded(
      BuildContext context, ColorScheme cs, Widget header) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: _expandedBody(context, cs),
          ),
        ],
      ),
    );
  }

  Widget _expandedBody(BuildContext context, ColorScheme cs) {
    // Section Pengaturan berbentuk dropdown (header bisa diklik) agar
    // kartu tidak terlalu panjang ke bawah.
    final settingsSection = Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      // Material transparan agar ink splash ListTile tidak tertutup DecoratedBox.
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: _settingsOpen,
        onExpansionChanged: (v) => setState(() => _settingsOpen = v),
        leading: Icon(Icons.tune, size: 18, color: cs.primary),
        title: Text(
          'Pengaturan',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
          ),
        ),
        children: [
          QuestionRequiredSwitch(
            value: q.isRequired,
            onChanged: (v) {
              // Samakan web: isRequired independen dari isScorable/kunci/poin.
              q.isRequired = v;
              widget.onChanged();
            },
          ),
          const Divider(height: 32),
          _sectionTitle(Icons.attach_file, 'Media', cs),
          const SizedBox(height: 14),
          QuestionMediaSection(
            draft: q,
            uploading: _uploading,
            onPickImage: _pickQuestionImage,
            onPickAudio: _pickQuestionAudio,
            onChanged: widget.onChanged,
          ),
        ],
        ),
      ),
    );
    final textAndAnswer = [
      QuestionTextSection(
        draft: q,
        preview: false,
        onPreviewChanged: (_) {},
        onTypeChanged: _onTypeChanged,
      ),
      const Divider(height: 32),
      _sectionTitle(Icons.rule, 'Jawaban', cs),
      const SizedBox(height: 14),
      QuestionAnswerSection(
        draft: q,
        onChanged: widget.onChanged,
      ),
    ];
    final settingsAndMedia = [
      settingsSection,
    ];
    if (isExpanded(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: textAndAnswer,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: settingsAndMedia,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...textAndAnswer,
        const SizedBox(height: 18),
        ...settingsAndMedia,
      ],
    );
  }
}