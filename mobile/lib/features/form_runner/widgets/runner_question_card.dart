import 'package:flutter/material.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/answer_fields.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/features/form_runner/controllers/runner_answer_store.dart';
import 'package:form_up/features/form_runner/widgets/question_audio_player.dart';
import 'package:form_up/features/form_runner/widgets/question_image.dart';

/// Kartu satu soal pada step pengisian
class RunnerQuestionCard extends StatelessWidget {
  final GlobalKey cardKey;
  final int index;
  final PublicQuestion question;
  final double zoom;
  final bool hasError;
  final TextEditingController? essayController;
  final FocusNode? essayFocusNode;
  final int? singleValue;
  final Set<int> multiValue;
  final String? tfValue;
  final DateTime? datetimeValue;
  final ValueChanged<String> onEssayChanged;
  final ValueChanged<int?> onSingleChanged;
  final ValueChanged<Set<int>> onMultiChanged;
  final ValueChanged<String?> onTfChanged;
  final VoidCallback onPickDateTime;

  const RunnerQuestionCard({
    super.key,
    required this.cardKey,
    required this.index,
    required this.question,
    required this.hasError,
    this.zoom = 1.0,
    required this.essayController,
    required this.essayFocusNode,
    required this.singleValue,
    required this.multiValue,
    required this.tfValue,
    required this.datetimeValue,
    required this.onEssayChanged,
    required this.onSingleChanged,
    required this.onMultiChanged,
    required this.onTfChanged,
    required this.onPickDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    double zs(double v) => (v * zoom).clamp(10, 48).toDouble();
    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
        border: Border.all(
          color: hasError ? const Color(0xFFC0392B) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. ',
                  style: TextStyle(
                    fontSize: zs(15),
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                Expanded(
                  child: RichTextView(
                    text: q.question,
                    zoom: zoom,
                    style: TextStyle(
                      fontSize: zs(15),
                      fontFamily: kFontBold,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
                if (q.isRequired == true)
                  const Text(
                    "*",
                    style: TextStyle(color: Color(0xFFC0392B), fontSize: 16),
                  ),
              ],
            ),
          ),
          // Gambar soal (jika dilampirkan)
          if (q.questionImage != null && q.questionImage!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            QuestionImage(url: q.questionImage!),
          ],
          // Audio soal (jika dilampirkan)
          if (q.questionAudio != null && q.questionAudio!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            QuestionAudioPlayer(url: q.questionAudio!),
          ],
          const SizedBox(height: 12),
          AnswerFields(
            zoom: zoom,
            typeId: q.typeId,
            options: [
              for (final o in q.options) AnswerOption(o.id, o.optionText),
            ],
            essayController: essayController,
            essayFocusNode: essayFocusNode,
            onEssayChanged: onEssayChanged,
            singleValue: singleValue,
            multiValue: multiValue,
            tfValue: tfValue,
            dateLabel: datetimeValue == null
                ? null
                : formatRunnerDateTime(datetimeValue!),
            onSingleChanged: onSingleChanged,
            onMultiChanged: onMultiChanged,
            onTfChanged: onTfChanged,
            onPickDateTime: onPickDateTime,
          ),
        ],
      ),
    );
  }
}
