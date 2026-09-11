import 'package:flutter/material.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/core/widgets/full_screen_image_viewer.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

class AnswerOption {
  final int id;
  final String text;
  final String? image;
  const AnswerOption(this.id, this.text, [this.image]);
}

/// Warna status hasil (benar/salah) yang adaptif tema: terang memakai
/// hijau/merah baku, gelap diterangkan agar terbaca di atas permukaan gelap.
Color resultStatusFg(BuildContext context, bool good) {
  if (Theme.of(context).brightness != Brightness.dark) {
    return good ? const Color(0xFF2E7D32) : const Color(0xFFC0392B);
  }
  return good ? const Color(0xFF81C784) : const Color(0xFFE57373);
}

/// Dekorasi blok status hasil: terang = filled pastel; gelap = stroke saja
/// (transparan + border) agar tidak terlalu kontras tapi tetap terbaca.
BoxDecoration resultStatusDecoration(BuildContext context, bool good) {
  final fg = resultStatusFg(context, good);
  if (Theme.of(context).brightness != Brightness.dark) {
    return BoxDecoration(
      color: good ? const Color(0xFFE3F4E8) : const Color(0xFFFDECEA),
      borderRadius: BorderRadius.circular(10),
    );
  }
  return BoxDecoration(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: fg.withValues(alpha: 0.7)),
  );
}

/// Input jawaban per tipe soal
class AnswerFields extends StatelessWidget {
  final int typeId;
  final List<AnswerOption> options;
  final TextEditingController? essayController;
  final FocusNode? essayFocusNode;
  final ValueChanged<String>? onEssayChanged;
  final int? singleValue;
  final Set<int> multiValue;
  final String? tfValue;
  final String? dateLabel;
  final ValueChanged<int?>? onSingleChanged;
  final ValueChanged<Set<int>>? onMultiChanged;
  final ValueChanged<String?>? onTfChanged;
  final VoidCallback? onPickDateTime;
  final double zoom;

  /// Mode ujian dengan cegah salin-tempel: sembunyikan menu konteks
  /// (salin/tempel) dan matikan seleksi interaktif pada field esai.
  final bool disablePaste;
  const AnswerFields({
    super.key,
    required this.typeId,
    this.options = const [],
    this.essayController,
    this.essayFocusNode,
    this.onEssayChanged,
    this.singleValue,
    this.multiValue = const {},
    this.tfValue,
    this.dateLabel,
    this.onSingleChanged,
    this.onMultiChanged,
    this.onTfChanged,
    this.onPickDateTime,
    this.zoom = 1.0,
    this.disablePaste = false,
  });
  double _zs(double v) => (v * zoom).clamp(10, 48).toDouble();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (typeId) {
      case 1: // Essay
        return TextField(
          controller: essayController,
          focusNode: essayFocusNode,
          maxLines: 3,
          onChanged: onEssayChanged,
          enableInteractiveSelection: !disablePaste,
          contextMenuBuilder: disablePaste
              ? (context, editableTextState) => const SizedBox.shrink()
              : null,
          style: TextStyle(fontSize: _zs(14)),
          decoration: _decoration("Tulis jawaban Anda..."),
        );
      case 2: // Multiple Choice
        return Material(
          type: MaterialType.transparency,
          child: RadioGroup<int>(
            groupValue: singleValue,
            onChanged: onSingleChanged ?? (_) {},
            child: Column(
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0)
                     Divider(
                      height: 1,
                      thickness: 1,
                      color: cs.surfaceContainerHighest,
                    ),
                  _buildChoiceOption(context, 
                    index: i,
                    text: options[i].text,
                    image: options[i].image,
                    onTap: onSingleChanged == null
                        ? null
                        : () => onSingleChanged!(options[i].id),
                    control: Radio<int>(
                      value: options[i].id,
                      activeColor: kAuthPrimary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      case 3: // Checkbox
        return Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0)
                   Divider(
                    height: 1,
                    thickness: 1,
                    color: cs.surfaceContainerHighest,
                  ),
                _buildChoiceOption(context, 
                  index: i,
                  text: options[i].text,
                  image: options[i].image,
                  onTap: onMultiChanged == null
                      ? null
                      : () => _toggleMulti(options[i].id),
                  control: Checkbox(
                    value: multiValue.contains(options[i].id),
                    onChanged: onMultiChanged == null
                        ? null
                        : (_) => _toggleMulti(options[i].id),
                    activeColor: kAuthPrimary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ],
          ),
        );
      case 4: // Date Time
        return InkWell(
          onTap: onPickDateTime,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                 Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: cs.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dateLabel ?? "Pilih tanggal & waktu",
                    style: TextStyle(
                      fontSize: _zs(14),
                      color: dateLabel == null ? cs.onSurfaceVariant : cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case 5: // True/False
        return Row(
          children: [
            Expanded(
              child: _chip(context, 
                "Benar",
                tfValue == 'Benar',
                onTfChanged == null ? null : () => onTfChanged!('Benar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _chip(context, 
                "Salah",
                tfValue == 'Salah',
                onTfChanged == null ? null : () => onTfChanged!('Salah'),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _chip(BuildContext context, String label, bool selected, VoidCallback? onTap) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: _zs(14),
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) => formUpInputDecoration(hintText: hint);

  void _toggleMulti(int optionId) {
    final selected = Set<int>.of(multiValue);
    if (selected.contains(optionId)) {
      selected.remove(optionId);
    } else {
      selected.add(optionId);
    }
    onMultiChanged!(selected);
  }

  /// Baris opsi pilihan ganda/checkbox:
  /// kontrol (radio/checkbox) + teks opsi format "A. {text}".
  /// Bila opsi punya gambar: thumbnail 56px, ketuk untuk zoom.
  Widget _buildChoiceOption(BuildContext context, {
    required int index,
    required String text,
    String? image,
    required Widget control,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final letter = String.fromCharCode(65 + index);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            control,
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                '$letter. ',
                style: TextStyle(
                  fontSize: _zs(14),
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: cs.onSurface,
                  height: 1.3,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: RichTextView(
                  text: text,
                  zoom: zoom,
                  style: TextStyle(
                    fontSize: _zs(14),
                    color: cs.onSurface,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            if (image != null && image.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => showFullScreenImage(
                    context, profileImageUrl(image)),
                child: CachedRemoteImage(
                  url: profileImageUrl(image),
                  height: 56,
                  width: 56,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ResultOptionsList extends StatelessWidget {
  final List<String> options;
  final String? answerText;
  final List<String> selectedOptions;
  final String? correctAnswer;
  final bool showScore;
  final bool? isCorrect;

  const ResultOptionsList({
    super.key,
    required this.options,
    this.answerText,
    this.selectedOptions = const [],
    this.correctAnswer,
    this.showScore = false,
    this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    final selected = selectedOptions.isNotEmpty
        ? selectedOptions
        : (answerText != null && answerText!.isNotEmpty ? [answerText!] : <String>[]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _OptionResultRow(
              letter: String.fromCharCode(65 + i),
              option: options[i],
              isSelected: selected.contains(options[i]),
              isCorrectOption:
                  showScore && correctAnswer != null && options[i] == correctAnswer,
              userIsCorrect: isCorrect,
            ),
          ),
      ],
    );
  }
}

/// Status pewarnaan satu baris opsi hasil
enum _OptionStatus { neutral, selectedNeutral, userCorrect, userWrong, correctKey }

class _OptionResultRow extends StatelessWidget {
  final String letter;
  final String option;
  final bool isSelected;
  final bool isCorrectOption;
  final bool? userIsCorrect;

  const _OptionResultRow({
    required this.letter,
    required this.option,
    required this.isSelected,
    required this.isCorrectOption,
    required this.userIsCorrect,
  });

  _OptionStatus get _status {
    if (!showColors) {
      return isSelected ? _OptionStatus.selectedNeutral : _OptionStatus.neutral;
    }
    // Jawaban user BENAR: cukup opsi user hijau.
    if (isSelected && userIsCorrect == true) return _OptionStatus.userCorrect;
    // Jawaban user SALAH: opsi user merah + kunci jawaban hijau.
    if (isSelected && userIsCorrect == false) return _OptionStatus.userWrong;
    if (!isSelected && isCorrectOption) return _OptionStatus.correctKey;
    if (isSelected) return _OptionStatus.selectedNeutral;
    return _OptionStatus.neutral;
  }

  bool get showColors => userIsCorrect != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final goodFg = resultStatusFg(context, true);
    final badFg = resultStatusFg(context, false);

    final (bg, fg, icon) = switch (_status) {
      _OptionStatus.userCorrect => (
          null,
          goodFg,
          Icon(Icons.check_circle, size: 16, color: goodFg),
        ),
      _OptionStatus.correctKey => (
          null,
          goodFg,
          Icon(Icons.check_circle, size: 16, color: goodFg),
        ),
      _OptionStatus.userWrong => (
          null,
          badFg,
          Icon(Icons.cancel, size: 16, color: badFg),
        ),
      _OptionStatus.selectedNeutral => (
          const Color(0xFFE0F2F1),
          cs.primary,
          Icon(Icons.radio_button_checked, size: 16, color: cs.primary),
        ),
      _OptionStatus.neutral => (
          cs.surfaceContainerHighest,
          cs.onSurface,
          null,
        ),
    };
    // Blok benar/salah memakai dekorasi status adaptif-tema (filled di
    // terang, stroke di gelap); netral memakai fill biasa.
    final bool isStatus =
        _status == _OptionStatus.userCorrect ||
        _status == _OptionStatus.correctKey ||
        _status == _OptionStatus.userWrong;
    final decoration = isStatus
        ? resultStatusDecoration(
            context, _status != _OptionStatus.userWrong)
        : BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: decoration,
      child: Row(
        children: [
          Text(
            letter,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: fg,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichTextView(
              text: option,
              style: TextStyle(fontSize: 13, color: fg),
            ),
          ),
          ?icon,
        ],
      ),
    );
  }
}

