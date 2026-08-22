import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/form_service.dart';

/// Validasi satu draf soal sebelum disimpan.
/// Mengembalikan pesan error, atau null bila valid.
String? validateQuestionDraft(QuestionDraft q) {
  final questionText = q.question.document.toPlainText().trim();
  if (questionText.isEmpty) {
    return "Teks pertanyaan tidak boleh kosong";
  }
  if (q.hasOptions) {
    if (q.options.isEmpty) {
      return "Tambahkan opsi pada pertanyaan pilihan";
    }
    for (final o in q.options) {
      if (o.text.document.toPlainText().trim().isEmpty) {
        return "Teks opsi tidak boleh kosong";
      }
    }
  }
  return null;
}

/// Validasi seluruh daftar draf soal (dipakai saat simpan kelola soal).
/// Mengembalikan pesan error pertama, atau null bila semua valid.
String? validateQuestionsList(List<QuestionDraft> questions) {
  if (questions.isEmpty) {
    return "Tambahkan minimal 1 pertanyaan";
  }
  for (final q in questions) {
    final error = validateQuestionDraft(q);
    if (error != null) return error;
  }
  return null;
}

/// Ubah data soal dari API menjadi draf soal beserta opsinya.
List<QuestionDraft> draftsFromQuestions(List<QuestionData> questions) {
  final drafts = <QuestionDraft>[];
  for (final q in questions) {
    final draft = QuestionDraft(
      q.typeId,
      id: q.id,
      question: q.question,
      correctAnswer: q.correctAnswer ?? '',
      isRequired: q.isRequired ?? true,
      randomizeOptions: q.randomizeOptions ?? false,
      questionImage: q.questionImage,
      questionAudio: q.questionAudio,
    );
    for (final o in q.options) {
      draft.options.add(OptionDraft(
        id: o.id,
        text: o.optionText,
        isCorrect: o.isCorrect ?? false,
      ));
    }
    drafts.add(draft);
  }
  return drafts;
}
