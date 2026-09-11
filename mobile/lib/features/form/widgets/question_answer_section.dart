import 'package:flutter/material.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:image_picker/image_picker.dart';

import 'question_image_source_sheet.dart';

/// Isi section "Jawaban": benar/salah, esai, atau daftar opsi
class QuestionAnswerSection extends StatelessWidget {
  final QuestionDraft draft;
  final VoidCallback onChanged;
  final Key? optionsKey;

  const QuestionAnswerSection({
    super.key,
    required this.draft,
    required this.onChanged,
    this.optionsKey,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = draft;
    // Samakan web FormBuilder.jsx: isScorable adalah toggle eksplisit
    // "Hitung ke Skor (Dinilai)", independen dari isRequired.
    // Jangan menimpa isScorable otomatis di build — biarkan pilihan user
    // (atau hasil load dari API) yang jadi sumber kebenaran, supaya kunci
    // jawaban + poin manual tidak hilang dan tetap terkirim ke backend.
    final scorable = q.isScorable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Checkbox(
              value: scorable,
              activeColor: cs.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (_) {
                q.isScorable = !scorable;
                if (!q.isScorable) q.points = null;
                onChanged();
              },
            ),
            Expanded(
              child: Text(
                "Hitung ke Skor (Dinilai)",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
            ),
          ],
        ),
        if (!scorable)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Soal ini Tidak Dinilai (pengumpulan data). Tidak memerlukan kunci dan tidak memengaruhi skor.',
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
          ),
        if (scorable) _buildAnswerContent(context),
        if (scorable) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                "Poin Soal",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: TextFormField(
                  key: ValueKey('points_${q.points}'),
                  initialValue: q.points?.toString() ?? '',
                  keyboardType: TextInputType.number,
                  decoration: formUpInputDecoration(hintText: "Kosong = sama rata").copyWith(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) {
                    if (v.trim().isEmpty) {
                      q.points = null;
                    } else {
                      q.points = int.tryParse(v);
                    }
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Otomatis",
                style: TextStyle(fontSize: 12, color: cs.onSurface),
              ),
              const SizedBox(width: 4),
              Switch(
                value: q.points == null,
                activeTrackColor: cs.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) {
                  if (v) {
                    q.points = null;
                  } else {
                    q.points = 1;
                  }
                  onChanged();
                },
              ),
            ],
          ),
          Text(
            q.points == null ? "Bobot otomatis sama rata" : "Bobot manual",
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  Widget _buildAnswerContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = draft;
    if (q.typeId == 5) return _buildTrueFalseAnswer(q, onChanged);
    if (q.typeId == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kunci Jawaban',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: q.correctAnswer,
            maxLines: null,
            enabled: q.isScorable,
            decoration: _fieldDecoration(
              "Kunci jawaban untuk kuis",
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      );
    }
    if (q.hasOptions) {
      return Column(
        key: optionsKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Opsi Jawaban',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: cs.primary,
                ),
              ),
              SizedBox(width: 2),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: kDangerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var oi = 0; oi < q.options.length; oi++)
            _OptionRow(
              index: oi,
              draft: q,
              onChanged: onChanged,
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                q.options.add(OptionDraft());
                onChanged();
              },
              icon: Icon(
                Icons.add_circle_outline,
                size: 18,
                color: cs.primary,
              ),
              label: Text(
                "Tambahkan opsi",
                style: TextStyle(color: cs.primary),
              ),
            ),
          ),
        ],
      );
    }
    return Text(
      'Jawaban tanggal & waktu diisi responden langsung.',
      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
    );
  }
}

Widget _buildTrueFalseAnswer(QuestionDraft q, VoidCallback onChanged) {
  final enabled = q.isScorable;
  return Opacity(
    opacity: enabled ? 1 : 0.5,
    child: Row(
      children: [
        Expanded(
          child: _AnswerChip(
            "Benar",
            q.correctAnswer.text == 'Benar',
            enabled
                ? () {
                    q.correctAnswer.text = 'Benar';
                    onChanged();
                  }
                : () {},
            enabled: enabled,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AnswerChip(
            "Salah",
            q.correctAnswer.text == 'Salah',
            enabled
                ? () {
                    q.correctAnswer.text = 'Salah';
                    onChanged();
                  }
                : () {},
            enabled: enabled,
          ),
        ),
      ],
    ),
  );
}

/// Chip pilihan jawaban benar/salah
class _AnswerChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  const _AnswerChip(this.label, this.selected, this.onTap, {this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Satu baris opsi jawaban (radio/checkbox + editor + gambar + hapus)
class _OptionRow extends StatefulWidget {
  final int index;
  final QuestionDraft draft;
  final VoidCallback onChanged;

  const _OptionRow({
    required this.index,
    required this.draft,
    required this.onChanged,
  });

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  bool _picking = false;

  Future<void> _pickImage() async {
    final o = widget.draft.options[widget.index];
    final source = await showQuestionImageSourceSheet(context);
    if (source == null || !mounted) return;
    setState(() => _picking = true);
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
        showAuthToast(context, 'Gambar maksimal 10 MB', isError: true);
        return;
      }
      setState(() {
        o.pendingImageBytes = bytes;
        o.pendingImageName = 'option.jpg';
        // Nilai final optionImage ditetapkan setelah soal disimpan.
        o.optionImage = null;
      });
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removeImage() {
    final o = widget.draft.options[widget.index];
    setState(() {
      o.optionImage = null;
      o.pendingImageBytes = null;
      o.pendingImageName = null;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = widget.draft;
    final o = q.options[widget.index];
    final singleSelect = q.typeId == 2;
    final hasImage =
        o.optionImage != null || o.pendingImageBytes != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: !q.isScorable
                    ? null
                    : () {
                        if (singleSelect) {
                          for (final opt in q.options) {
                            opt.isCorrect = false;
                          }
                          o.isCorrect = true;
                        } else {
                          o.isCorrect = !o.isCorrect;
                        }
                        widget.onChanged();
                      },
                child: Icon(
                  singleSelect
                      ? (o.isCorrect
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked)
                      : (o.isCorrect
                            ? Icons.check_box
                            : Icons.check_box_outline_blank),
                  color: o.isCorrect ? cs.primary : cs.outline,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichTextEditor(
                  controller: o.text,
                  hint: 'Opsi ${widget.index + 1}',
                  minHeight: 40,
                ),
              ),
              IconButton(
                tooltip: hasImage ? 'Ganti gambar opsi' : 'Tambah gambar opsi',
                icon: _picking
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      )
                    : Icon(
                        hasImage
                            ? Icons.image_outlined
                            : Icons.add_photo_alternate_outlined,
                        size: 20,
                        color: hasImage ? cs.primary : cs.onSurfaceVariant,
                      ),
                onPressed: _picking ? null : _pickImage,
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                onPressed: () {
                  o.text.dispose();
                  q.options.removeAt(widget.index);
                  widget.onChanged();
                },
              ),
            ],
          ),
          // Pratinjau gambar opsi.
          if (o.pendingImageBytes != null) ...[
            const SizedBox(height: 6),
            _optionImagePreview(
              cs,
              Image.memory(
                o.pendingImageBytes!,
                height: 90,
                width: 140,
                fit: BoxFit.cover,
              ),
              '(belum tersimpan)',
              onRemove: _removeImage,
            ),
          ] else if (o.optionImage != null) ...[
            const SizedBox(height: 6),
            _optionImagePreview(
              cs,
              CachedRemoteImage(
                url: profileImageUrl(o.optionImage),
                height: 90,
                width: 140,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(8),
              ),
              null,
              onRemove: _removeImage,
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionImagePreview(
    ColorScheme cs,
    Widget image,
    String? caption, {
    required VoidCallback onRemove,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 30),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: image,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (caption != null)
                Text(
                  'Pratinjau gambar $caption',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline,
                    size: 15, color: Color(0xFFC0392B)),
                label: const Text(
                  'Hapus gambar',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFFC0392B)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration(String hint) => formUpInputDecoration(hintText: hint);
