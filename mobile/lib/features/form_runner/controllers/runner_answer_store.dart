import 'package:flutter/material.dart';
import 'package:form_up/core/services/public_form_service.dart';

/// Penyimpanan jawaban responden untuk semua tipe soal pada form runner.
class RunnerAnswerStore {
  final Map<int, TextEditingController> textAnswers = {};
  final Map<int, int?> singleAnswers = {};
  final Map<int, Set<int>> multiAnswers = {};
  final Map<int, String?> tfAnswers = {};
  final Map<int, DateTime?> datetimeAnswers = {};
  final Map<int, FocusNode> essayFocusNodes = {};
  final List<GlobalKey> questionKeys = [];

  /// Inisialisasi jawaban kosong sesuai tipe tiap soal.
  void init(List<PublicQuestion> questions) {    textAnswers.clear();
    singleAnswers.clear();
    multiAnswers.clear();
    tfAnswers.clear();
    datetimeAnswers.clear();
    essayFocusNodes.clear();
    questionKeys
      ..clear()
      ..addAll([for (var i = 0; i < questions.length; i++) GlobalKey()]);
    for (final q in questions) {
      switch (q.typeId) {
        case 1: // Essay
          textAnswers[q.id] = TextEditingController();
          essayFocusNodes[q.id] = FocusNode();
          break;
        case 4: // Date Time
          datetimeAnswers[q.id] = null;
          break;
        case 5: // True/False
          tfAnswers[q.id] = null;
          break;
        case 2: // Multiple Choice
          singleAnswers[q.id] = null;
          break;
        case 3: // Checkbox
          multiAnswers[q.id] = {};
          break;
      }
    }
  }

  /// Siapkan pengerjaan ulang: buang controller jawaban lama lalu isi ulang.
  void reinit(List<PublicQuestion> questions) {
    for (final c in textAnswers.values) {
      c.dispose();
    }
    init(questions);
  }

  void dispose() {
    for (final c in textAnswers.values) {
      c.dispose();
    }
    for (final f in essayFocusNodes.values) {
      f.dispose();
    }
  }

  /// Apakah soal sudah dijawab.
  bool isAnswered(PublicQuestion q) {
    switch (q.typeId) {
      case 1:
        return (textAnswers[q.id]?.text.trim() ?? '').isNotEmpty;
      case 2:
        return singleAnswers[q.id] != null;
      case 3:
        return (multiAnswers[q.id] ?? {}).isNotEmpty;
      case 4:
        return datetimeAnswers[q.id] != null;
      case 5:
        return tfAnswers[q.id] != null;
      default:
        return true;
    }
  }

  /// Index soal wajib pertama yang belum dijawab (urut dari atas), atau null.
  int? firstUnansweredIndex(List<PublicQuestion> questions) {
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      if (q.isRequired == true && !isAnswered(q)) return i;
    }
    return null;
  }

  /// ID semua soal wajib yang belum dijawab.
  Set<int> unansweredIds(List<PublicQuestion> questions) {
    return {
      for (final q in questions)
        if (q.isRequired == true && !isAnswered(q)) q.id,
    };
  }

  /// Kumpulkan jawaban apa adanya (tanpa validasi wajib) — dipakai auto submit.
  List<Map<String, dynamic>> collectAutoAnswers(
    List<PublicQuestion> questions,
  ) {
    final answers = <Map<String, dynamic>>[];
    for (final q in questions) {
      switch (q.typeId) {
        case 1: // Essay
          final text = textAnswers[q.id]?.text.trim() ?? '';
          if (text.isNotEmpty) {
            answers.add({'questionId': q.id, 'answerValue': text});
          }
          break;
        case 2: // Multiple Choice
          final optionId = singleAnswers[q.id];
          if (optionId != null) {
            answers.add({'questionId': q.id, 'optionId': optionId});
          }
          break;
        case 3: // Checkbox
          for (final oid in multiAnswers[q.id] ?? {}) {
            answers.add({'questionId': q.id, 'optionId': oid});
          }
          break;
        case 4: // Date Time
          final dt = datetimeAnswers[q.id];
          if (dt != null) {
            answers.add({
              'questionId': q.id,
              'answerValue': formatRunnerDateTime(dt),
            });
          }
          break;
        case 5: // True/False
          final tf = tfAnswers[q.id];
          if (tf != null) {
            answers.add({'questionId': q.id, 'answerValue': tf});
          }
          break;
      }
    }
    return answers;
  }

  /// Apakah ada jawaban sama sekali.
  bool hasAnyAnswer(List<PublicQuestion> questions) =>
      questions.any((q) => isAnswered(q));

  /// Kumpulkan jawaban dengan pemeriksaan wajib per soal.
  /// Mengembalikan null bila ada soal wajib yang belum dijawab.
  List<Map<String, dynamic>>? collectValidatedAnswers(
    List<PublicQuestion> questions,
  ) {
    final answers = <Map<String, dynamic>>[];
    for (final q in questions) {
      switch (q.typeId) {
        case 1: // Essay
          final text = textAnswers[q.id]?.text.trim() ?? '';
          if (q.isRequired == true && text.isEmpty) {
            return null;
          }
          if (text.isNotEmpty) {
            answers.add({'questionId': q.id, 'answerValue': text});
          }
          break;
        case 2: // Multiple Choice
          final optionId = singleAnswers[q.id];
          if (q.isRequired == true && optionId == null) {
            return null;
          }
          if (optionId != null) {
            answers.add({'questionId': q.id, 'optionId': optionId});
          }
          break;
        case 3: // Checkbox
          final selected = multiAnswers[q.id] ?? {};
          if (q.isRequired == true && selected.isEmpty) {
            return null;
          }
          for (final oid in selected) {
            answers.add({'questionId': q.id, 'optionId': oid});
          }
          break;
        case 4: // Date Time
          final dt = datetimeAnswers[q.id];
          if (q.isRequired == true && dt == null) {
            return null;
          }
          if (dt != null) {
            answers.add({
              'questionId': q.id,
              'answerValue': formatRunnerDateTime(dt),
            });
          }
          break;
        case 5: // True/False
          final tf = tfAnswers[q.id];
          if (q.isRequired == true && tf == null) {
            return null;
          }
          if (tf != null) {
            answers.add({'questionId': q.id, 'answerValue': tf});
          }
          break;
      }
    }
    return answers;
  }
}

/// Format tanggal-waktu untuk label jawaban runner.
String formatRunnerDateTime(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final local = dt.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return "${local.day} ${months[local.month - 1]} ${local.year}, $hh:$mm";
}

/// Format durasi dari detik menjadi "X jam Y menit" / "Y menit".
String formatRunnerDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0 && m > 0) return "$h jam $m menit";
  if (h > 0) return "$h jam";
  if (m > 0) return "$m menit";
  return "$seconds detik";
}
