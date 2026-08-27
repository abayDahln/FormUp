import 'package:flutter/material.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/widgets/answer_fields.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Step hasil pengerjaan: skor, pembahasan, dan aksi lanjutan
class RunnerResultView extends StatelessWidget {
  final PublicFormResult result;
  final bool isLoggedIn;
  final VoidCallback onReset;
  final VoidCallback onFeedback;

  const RunnerResultView({
    super.key,
    required this.result,
    required this.isLoggedIn,
    required this.onReset,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result.showScore) ...[
            _ScoreCard(result: result),
            const SizedBox(height: 16),
          ],
          Text(
            result.showScore ? "Pembahasan" : "Jawaban Anda",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (result.answers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                "Belum ada jawaban.",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            )
          else
            for (var i = 0; i < result.answers.length; i++) ...[
              _ResultCard(
                index: i,
                answer: result.answers[i],
                showScore: result.showScore,
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh, size: 18, color: kAuthPrimary),
            label: const Text(
              "Kerjakan Form Lain",
              style: TextStyle(color: kAuthPrimary),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kAuthPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (isLoggedIn) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onFeedback,
              icon: const Icon(Icons.message_outlined, size: 18, color: kAuthPrimary),
              label: const Text(
                "Kirim Feedback",
                style: TextStyle(color: kAuthPrimary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kAuthPrimary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kartu skor besar dengan statistik benar/salah/dijawab
class _ScoreCard extends StatelessWidget {
  final PublicFormResult result;

  const _ScoreCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final score = result.score;
    final color = score == null
        ? Colors.grey
        : (score >= 75
              ? const Color(0xFF2E7D32)
              : score >= 50
                  ? const Color(0xFFB26A00)
                  : const Color(0xFFC0392B));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        children: [
          Text(
            "Skor Anda",
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            score == null ? "—" : "${score.toStringAsFixed(1)}%",
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _scoreStat(
                "${result.correctCount}",
                "Benar",
                const Color(0xFF2E7D32),
              ),
              _scoreStat(
                "${result.wrongCount}",
                "Salah",
                const Color(0xFFC0392B),
              ),
              _scoreStat(
                "${result.answeredCount}",
                "Dijawab",
                kAuthPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}

/// Kartu satu jawaban pada pembahasan hasil runner
class _ResultCard extends StatelessWidget {
  final int index;
  final PublicResultAnswer answer;
  final bool showScore;

  const _ResultCard({
    required this.index,
    required this.answer,
    required this.showScore,
  });

  @override
  Widget build(BuildContext context) {
    final a = answer;
    final answered = a.answerText != null && a.answerText!.isNotEmpty;
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
              Text(
                '${index + 1}. ',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black87,
                ),
              ),
              Expanded(
                child: RichTextView(
                  text: a.question,
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
                  color: a.isCorrect! ? const Color(0xFF2E7D32) : const Color(0xFFC0392B),
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 10),
          ResultOptionsList(
            options: a.options,
            answerText: a.answerText,
            correctAnswer: a.correctAnswer,
            showScore: showScore,
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Jawaban Anda",
                  style: TextStyle(fontSize: 11, color: Colors.black45),
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
