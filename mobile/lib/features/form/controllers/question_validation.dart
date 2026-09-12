import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/form_service.dart';

/// Validasi satu draf soal sebelum disimpan.
/// Mengembalikan pesan error, atau null bila valid.
String? validateQuestionDraft(QuestionDraft q) {
  final questionText = q.question.document.toPlainText().trim();
  if (questionText.isEmpty) {
    return "Teks pertanyaan tidak boleh kosong";
  }
  // B6: tipe tanggal & waktu tidak dapat dinilai — blokir, bukan diam.
  if (q.typeId == 4 && q.isScorable) {
    return "Soal tanggal & waktu tidak dapat dinilai";
  }
  if (q.hasOptions) {
    if (q.options.isEmpty) {
      return "Tambahkan opsi pada pertanyaan pilihan";
    }
    if (q.typeId == 2 && q.options.length < 2) {
      return "Pilihan ganda butuh minimal 2 opsi";
    }
    final seen = <String>{};
    for (final o in q.options) {
      final text = o.text.document.toPlainText().trim();
      if (text.isEmpty) {
        return "Teks opsi tidak boleh kosong";
      }
      if (!seen.add(text.toLowerCase())) {
        return 'Opsi "$text" duplikat';
      }
    }
    // B6: PG (pilihan tunggal) yang dinilai wajib tepat 1 kunci jawaban.
    if (q.typeId == 2 && q.isScorable) {
      final correct = q.options.where((o) => o.isCorrect).length;
      if (correct != 1) {
        return "Pilihan ganda bernilai wajib tepat 1 opsi benar";
      }
    }
    if (q.typeId == 3 && q.isScorable) {
      final correct = q.options.where((o) => o.isCorrect).length;
      if (correct == 0) {
        return "Tandai minimal 1 opsi benar untuk soal bernilai";
      }
    }
  }
  // B6: Benar/Salah yang dinilai hanya menerima kunci 'Benar'/'Salah'.
  if (q.typeId == 5 && q.isScorable) {
    final key = q.correctAnswer.text.trim();
    if (key != 'Benar' && key != 'Salah') {
      return "Soal benar/salah bernilai wajib kunci Benar atau Salah";
    }
  }
  if ((q.points ?? 0) < 0) {
    return "Bobot poin tidak boleh negatif";
  }
  if (q.isScorable &&
      q.typeId != 3 &&
      q.correctAnswer.text.trim().isEmpty &&
      !q.options.any((o) => o.isCorrect)) {
    return "Isi kunci jawaban untuk soal bernilai";
  }
  return null;
}

/// Validasi seluruh daftar draf soal (dipakai saat simpan kelola soal).
/// Mengembalikan pesan error pertama, atau null bila semua valid.
String? validateQuestionsList(
  List<QuestionDraft> questions, {
  bool allowEmpty = false,
}) {
  if (questions.isEmpty && !allowEmpty) {
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
    final hasCorrectAnswer = q.correctAnswer != null && q.correctAnswer!.trim().isNotEmpty;
    final hasCorrectOption = q.options.any((o) => o.isCorrect == true);
    final inferredScorable = q.points != null || hasCorrectAnswer || hasCorrectOption;
    final draft = QuestionDraft(
      q.typeId,
      id: q.id,
      question: q.question,
      correctAnswer: q.correctAnswer ?? '',
      isRequired: q.isRequired ?? true,
      randomizeOptions: q.randomizeOptions ?? false,
      isScorable: inferredScorable,
      points: q.points,
      questionImage: q.questionImage,
      questionAudio: q.questionAudio,
    );
    for (final o in q.options) {
      draft.options.add(OptionDraft(
        id: o.id,
        text: o.optionText,
        isCorrect: o.isCorrect ?? false,
        optionImage: o.optionImage,
      ));
    }
    drafts.add(draft);
  }
  return drafts;
}
