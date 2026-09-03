import 'package:flutter/material.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/widgets/answer_fields.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Kartu satu jawaban pada pembahasan hasil form
class HistoryAnswerCard extends StatelessWidget {
  final int index;
  final PublicResultAnswer answer;
  final bool showScore;
  final int? responseId;
  final int? formId;
  final VoidCallback? onScoreUpdated;

  const HistoryAnswerCard({
    super.key,
    required this.index,
    required this.answer,
    required this.showScore,
    this.responseId,
    this.formId,
    this.onScoreUpdated,
  });

  Future<void> _showGradeDialog(BuildContext context) async {
    if (responseId == null || answer.answerId == 0) {
      showAuthToast(context, 'ID jawaban tidak tersedia', isError: true);
      return;
    }
    final scoreCtrl = TextEditingController(text: answer.manualScore?.toString() ?? answer.earnedPoints?.toString() ?? '');
    bool? isCorrect = answer.isCorrectOverride ?? answer.isCorrect;
    final noteCtrl = TextEditingController(text: answer.overrideNote ?? '');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nilai Manual (AI-4)', style: TextStyle(fontFamily: kFontBold, fontSize: 14)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: scoreCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Skor manual (kosongkan untuk auto)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<bool?>(
            initialValue: isCorrect,
            decoration: const InputDecoration(labelText: 'Koreksi Benar/Salah'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Auto')),
              DropdownMenuItem(value: true, child: Text('Benar')),
              DropdownMenuItem(value: false, child: Text('Salah')),
            ],
            onChanged: (v) => setSt(() => isCorrect = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, {'score': scoreCtrl.text, 'isCorrect': isCorrect, 'note': noteCtrl.text}), child: const Text('Simpan')),
        ],
      )),
    );
    if (result == null) return;
    try {
      final rawScore = (result['score'] as String).trim();
      final manualScore = rawScore.isEmpty ? null : double.tryParse(rawScore);
      if (rawScore.isNotEmpty && manualScore == null) {
        showAuthToast(context, 'Skor harus angka', isError: true);
        return;
      }
      await FormService.updateAnswerScore(responseId!, answer.answerId, manualScore: manualScore, isCorrectOverride: result['isCorrect'] as bool?, overrideNote: (result['note'] as String).trim().isEmpty ? null : (result['note'] as String).trim());
      showAuthToast(context, 'Nilai diperbarui');
      onScoreUpdated?.call();
    } catch (e) {
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

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
          if (a.manualScore != null || a.earnedPoints != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF0F4F4), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.star, size: 14, color: Colors.black54),
                const SizedBox(width: 6),
                Text('Poin: ${a.manualScore ?? a.earnedPoints}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                if (a.isCorrectOverride != null) ...[
                  const SizedBox(width: 8),
                  Chip(label: Text(a.isCorrectOverride! ? 'Override: Benar' : 'Override: Salah', style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
                ],
              ]),
            ),
          ],
          if (responseId != null && formId != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showGradeDialog(context),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Nilai Manual', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}
