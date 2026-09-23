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

/// Hasil sanitasi daftar soal mentah dari AI sebelum dikirim ke server.
class AiSanitizeResult {
  /// Payload bersih siap kirim (hanya soal yang lolos).
  final List<Map<String, dynamic>> questions;

  /// Error per soal yang tak bisa diperbaiki otomatis (nomor 1-based).
  final List<String> errors;

  /// Jumlah perbaikan otomatis (kunci ganda → satu, huruf kunci, dsb).
  final int autoFixed;

  const AiSanitizeResult({
    required this.questions,
    required this.errors,
    required this.autoFixed,
  });

  bool get hasErrors => errors.isNotEmpty;
}

/// Bersihkan + validasi soal mentah dari AI (create_form / add_questions).
///
/// Menjamin data ambigu TAK PERNAH tersimpan:
/// - Pilihan ganda (typeId 2): TEPAT 1 kunci. Kunci ganda → pertahankan
///   pertama; tanpa kunci → cocokkan correctAnswer ke opsi; tetap hilang +
///   dinilai → error (tidak dikarang).
/// - Checkbox (3): minimal 1 kunci bila dinilai, else error.
/// - Benar/Salah (5): kunci dinormalisasi ke 'Benar'/'Salah'.
/// - Esai bernilai tanpa kunci → error.
/// - Tanpa niat menilai (tanpa points/kunci/flag) → seluruh kunci
///   dibersihkan (sesuai kebijakan: tanpa skor = tanpa kunci).
///
/// Tidak pernah melempar — caller WAJIB menggagalkan aksi bila
/// [AiSanitizeResult.hasErrors] agar data ambigu tidak tersimpan.
AiSanitizeResult sanitizeAiQuestions(List<dynamic> raw) {
  final questions = <Map<String, dynamic>>[];
  final errors = <String>[];
  var fixed = 0;

  for (var i = 0; i < raw.length; i++) {
    final n = i + 1;
    final e = raw[i];
    if (e is! Map) {
      errors.add('Soal #$n: format tidak dikenal');
      continue;
    }
    final m = Map<String, dynamic>.from(e);

    var typeId = m['typeId'] is num
        ? (m['typeId'] as num).toInt()
        : int.tryParse('${m['typeId']}');
    if (typeId == null || typeId < 1 || typeId > 5) {
      typeId = (m['options'] is List && (m['options'] as List).isNotEmpty)
          ? 2
          : 1;
      fixed++;
    }

    final text = '${m['question'] ?? ''}'.trim();
    if (text.isEmpty) {
      errors.add('Soal #$n: teks pertanyaan kosong');
      continue;
    }

    final isRequired = m['isRequired'] is bool ? m['isRequired'] as bool : true;

    int? points;
    if (m['points'] is num) {
      points = (m['points'] as num).toInt();
      if (points < 0) {
        points = 0;
        fixed++;
      }
    }

    var key = '${m['correctAnswer'] ?? ''}'.trim();

    // Normalisasi opsi → [{optionText, isCorrect}]. Opsi string polos
    // dianggap tanpa kunci; opsi kosong dibuang; duplikat digabung.
    final opts = <Map<String, dynamic>>[];
    if (m['options'] is List) {
      for (final o in (m['options'] as List)) {
        String t;
        var flag = false;
        if (o is String) {
          t = o.trim();
        } else if (o is Map) {
          t = '${o['optionText'] ?? o['text'] ?? ''}'.trim();
          flag = o['isCorrect'] == true;
        } else {
          t = '$o'.trim();
        }
        if (t.isEmpty) {
          fixed++;
          continue;
        }
        final dupIndex = opts.indexWhere(
          (x) => (x['optionText'] as String).toLowerCase() == t.toLowerCase(),
        );
        if (dupIndex >= 0) {
          if (flag && opts[dupIndex]['isCorrect'] != true) {
            opts[dupIndex]['isCorrect'] = true;
          }
          fixed++;
          continue;
        }
        opts.add({'optionText': t, 'isCorrect': flag});
      }
    }

    final isOptionType = typeId == 2 || typeId == 3;
    if (!isOptionType) opts.clear();

    if (typeId == 4) {
      // Tanggal & waktu tidak pernah dinilai.
      points = null;
      key = '';
    }

    // Ada niat menilai? (kebijakan: tanpa skor = tanpa kunci.)
    bool intended() =>
        points != null ||
        key.isNotEmpty ||
        opts.any((o) => o['isCorrect'] == true);

    if (typeId == 2) {
      if (opts.length < 2) {
        errors.add('Soal #$n (Pilihan Ganda): butuh minimal 2 opsi');
        continue;
      }
      var correctIdx = [
        for (var k = 0; k < opts.length; k++)
          if (opts[k]['isCorrect'] == true) k,
      ];
      if (correctIdx.length > 1) {
        for (final k in correctIdx.skip(1)) {
          opts[k]['isCorrect'] = false;
        }
        correctIdx = [correctIdx.first];
        fixed++;
      }
      if (correctIdx.isEmpty && key.isNotEmpty) {
        final hit = matchOptionIndex(opts, key);
        if (hit != null) {
          opts[hit]['isCorrect'] = true;
          correctIdx = [hit];
          fixed++;
        }
      }
      if (correctIdx.isEmpty) {
        if (intended()) {
          errors.add('Soal #$n (Pilihan Ganda): tidak ada kunci jawaban');
          continue;
        }
      } else {
        key = opts[correctIdx.first]['optionText'] as String;
      }
    } else if (typeId == 3) {
      if (!opts.any((o) => o['isCorrect'] == true) && key.isNotEmpty) {
        // Kunci bebas "A,C" → tandai semua opsi yang cocok.
        var anyHit = false;
        for (final part in key
            .split(RegExp(r'[,|;]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)) {
          final hit = matchOptionIndex(opts, part);
          if (hit != null) {
            opts[hit]['isCorrect'] = true;
            anyHit = true;
          }
        }
        if (anyHit) fixed++;
      }
      if (!opts.any((o) => o['isCorrect'] == true)) {
        if (intended()) {
          errors.add('Soal #$n (Checkbox): tandai minimal 1 opsi benar');
          continue;
        }
        key = '';
      } else {
        key = [
          for (final o in opts)
            if (o['isCorrect'] == true) o['optionText'] as String,
        ].join(', ');
      }
    } else if (typeId == 5) {
      final low = key.toLowerCase();
      if (low == 'benar' || low == 'true') {
        if (key != 'Benar') fixed++;
        key = 'Benar';
      } else if (low == 'salah' || low == 'false') {
        if (key != 'Salah') fixed++;
        key = 'Salah';
      } else if (key.isNotEmpty) {
        errors.add('Soal #$n (Benar/Salah): kunci harus "Benar" atau "Salah"');
        continue;
      } else if (intended()) {
        errors.add('Soal #$n (Benar/Salah): tidak ada kunci jawaban');
        continue;
      }
    } else if (typeId == 1) {
      if (key.isEmpty && points != null) {
        errors.add('Soal #$n (Esai bernilai): kunci jawaban kosong');
        continue;
      }
    }

    // Final: tanpa niat menilai → bersihkan seluruh kunci.
    final scorable = points != null ||
        key.isNotEmpty ||
        opts.any((o) => o['isCorrect'] == true);
    if (!scorable) {
      points = null;
      key = '';
      for (final o in opts) {
        o['isCorrect'] = false;
      }
    }

    questions.add({
      if (m['id'] != null) 'id': m['id'],
      if (m['questionOrder'] != null) 'questionOrder': m['questionOrder'],
      'typeId': typeId,
      'question': text,
      'isRequired': isRequired,
      'points': points,
      'correctAnswer': key.isEmpty ? null : key,
      if (isOptionType) 'options': opts,
    });
  }
  return AiSanitizeResult(
    questions: questions,
    errors: errors,
    autoFixed: fixed,
  );
}

/// Cocokkan kunci bebas ke indeks opsi: teks persis (case-insensitive),
/// huruf A-E, atau angka 1-based. Null bila tidak cocok.
int? matchOptionIndex(List<Map<String, dynamic>> opts, String key) {
  final k = key.trim();
  if (k.isEmpty) return null;
  for (var i = 0; i < opts.length; i++) {
    if ((opts[i]['optionText'] as String).toLowerCase() == k.toLowerCase()) {
      return i;
    }
  }
  if (k.length == 1) {
    final c = k.toUpperCase().codeUnitAt(0);
    if (c >= 65 && c < 65 + opts.length) return c - 65;
  }
  final num = int.tryParse(k);
  if (num != null && num >= 1 && num <= opts.length) return num - 1;
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
