import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Bangun payload JSON untuk menyimpan daftar draf soal.
List<Map<String, dynamic>> buildQuestionsPayload(List<QuestionDraft> questions) {
  return [
    for (final q in questions)
      {
        if (q.id != null) 'id': q.id,
        'typeId': q.typeId,
        'question': encodeRichText(q.question),
        'isRequired': q.isRequired,
        'randomizeOptions': q.randomizeOptions,
        if (q.correctAnswer.text.trim().isNotEmpty)
          'correctAnswer': q.correctAnswer.text.trim(),
        if (q.hasOptions)
          'options': [
            for (final o in q.options)
              {
                'optionText': o.text.document.toPlainText().trim(),
                'isCorrect': o.isCorrect,
              },
          ],
      },
  ];
}
