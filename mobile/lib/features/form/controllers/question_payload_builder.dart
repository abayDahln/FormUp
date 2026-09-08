import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Bangun payload JSON untuk menyimpan daftar draf soal.
/// Sesuai endpoint PUT /forms/{id}/questions — samakan web FormBuilder.jsx:
/// `isScorable` independen dari `isRequired`. Bila dinilai, kirim
/// `points` (null = bobot sama rata) & `correctAnswer`/`isCorrect` apa adanya;
/// bila tidak dinilai, kirim null/false agar backend (ResponseScorer.
/// CountScorable: Points/CorrectAnswer/IsCorrect) menganggap non-scorable.
List<Map<String, dynamic>> buildQuestionsPayload(List<QuestionDraft> questions) {
  return [
    for (var i = 0; i < questions.length; i++)
      {
        if (questions[i].id != null) 'id': questions[i].id,
        'typeId': questions[i].typeId,
        'question': encodeRichText(questions[i].question),
        'questionOrder': i + 1,
        'isRequired': questions[i].isRequired,
        'randomizeOptions': questions[i].randomizeOptions,
        'points': questions[i].isScorable ? questions[i].points : null,
        // Kirim eksplisit null bila dinilai tapi kunci kosong (ala web:
        // `correctAnswer: scorable ? (q.correctAnswer || null) : null`).
        'correctAnswer': questions[i].isScorable
            ? (questions[i].correctAnswer.text.trim().isEmpty
                ? null
                : questions[i].correctAnswer.text.trim())
            : null,
        if (questions[i].questionImage != null) 'questionImage': questions[i].questionImage,
        if (questions[i].questionAudio != null) 'questionAudio': questions[i].questionAudio,
        if (questions[i].hasOptions)
          'options': [
            for (final o in questions[i].options)
              {
                'optionText': encodeRichText(o.text).isEmpty ? o.text.document.toPlainText().trim() : encodeRichText(o.text),
                'isCorrect': questions[i].isScorable ? o.isCorrect : false,
              },
          ],
      },
  ];
}
