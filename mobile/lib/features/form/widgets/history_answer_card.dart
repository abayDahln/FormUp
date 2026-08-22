import 'package:flutter/material.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/widgets/answer_fields.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Kartu satu jawaban pada pembahasan hasil form
class HistoryAnswerCard extends StatelessWidget {
  final int index;
  final PublicResultAnswer answer;
  final bool showScore;

  const HistoryAnswerCard({
    super.key,
    required this.index,
    required this.answer,
    required this.showScore,
  });

  @override
  Widget build(BuildContext context) {
    final a = answer;
    final answered = a.answerText != null && a.answerText!.isNotEmpty;
    // Soal teks/essay dinilai benar/salah hanya jika ada kunci jawaban.
    final scorable = showScore && a.correctAnswer != null && a.correctAnswer!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichTextView(
                  text: a.question,
                  prefix: '${index + 1}. ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (showScore && a.isCorrect != null)
                Icon(
                  a.isCorrect! ? Icons.check_circle : Icons.cancel,
                  color: a.isCorrect!
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC0392B),
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 10),
          ResultOptionsList(
            options: a.options,
            answerText: a.answerText,
            selectedOptions: a.selectedOptions,
            correctAnswer: a.correctAnswer,
            showScore: showScore,
            isCorrect: a.isCorrect,
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: !scorable
                  ? const Color(0xFFF0F4F4)
                  : (a.isCorrect == true
                      ? const Color(0xFFE3F4E8) // jawaban benar: hijau
                      : const Color(0xFFFDECEA)), // jawaban salah: merah
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Jawaban Anda",
                  style: TextStyle(
                    fontSize: 11,
                    color: !scorable
                        ? Colors.black45
                        : (a.isCorrect == true
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC0392B)),
                  ),
                ),
                const SizedBox(height: 4),
                if (answered)
                  RichTextView(
                    text: a.answerText!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  )
                else
                  const Text(
                    "Tidak dijawab",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          if (showScore &&
              a.correctAnswer != null &&
              a.correctAnswer!.isNotEmpty &&
              a.correctAnswer != a.answerText) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F4E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Jawaban Benar",
                    style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
                  ),
                  const SizedBox(height: 4),
                  RichTextView(
                    text: a.correctAnswer!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
