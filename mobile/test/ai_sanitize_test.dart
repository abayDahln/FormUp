import 'package:flutter_test/flutter_test.dart';
import 'package:form_up/features/form/controllers/question_validation.dart';

/// Regresi kunci jawaban AI: PG wajib tepat 1 kunci, tanpa kunci + dinilai
/// wajib ditolak (tidak boleh tersimpan ambigu).
void main() {
  group('sanitizeAiQuestions', () {
    test('PG 2 kunci → pertahankan pertama', () {
      final r = sanitizeAiQuestions([
        {
          'typeId': 2,
          'question': 'Ibukota Indonesia?',
          'points': 10,
          'options': [
            {'optionText': 'Jakarta', 'isCorrect': true},
            {'optionText': 'Bandung', 'isCorrect': true},
            {'optionText': 'Surabaya', 'isCorrect': false},
          ],
        },
      ]);
      expect(r.hasErrors, isFalse);
      final opts = r.questions.first['options'] as List;
      expect(opts.where((o) => o['isCorrect'] == true).length, 1);
      expect(opts.firstWhere((o) => o['isCorrect'] == true)['optionText'],
          'Jakarta');
      expect(r.questions.first['correctAnswer'], 'Jakarta');
      expect(r.autoFixed, greaterThan(0));
    });

    test('PG tanpa kunci + dinilai → error, tidak lolos', () {
      final r = sanitizeAiQuestions([
        {
          'typeId': 2,
          'question': 'Ibukota Indonesia?',
          'points': 10,
          'options': [
            {'optionText': 'Jakarta'},
            {'optionText': 'Bandung'},
          ],
        },
      ]);
      expect(r.hasErrors, isTrue);
      expect(r.questions, isEmpty);
      expect(r.errors.first, contains('tidak ada kunci'));
    });

    test('PG tanpa kunci via huruf correctAnswer → cocok', () {
      final r = sanitizeAiQuestions([
        {
          'typeId': 2,
          'question': 'Ibukota Indonesia?',
          'correctAnswer': 'B',
          'options': ['Jakarta', 'Bandung', 'Surabaya'],
        },
      ]);
      expect(r.hasErrors, isFalse);
      final opts = r.questions.first['options'] as List;
      expect(opts[1]['isCorrect'], isTrue);
      expect(r.questions.first['correctAnswer'], 'Bandung');
    });

    test('PG tanpa skor + tanpa kunci → dibersihkan, lolos', () {
      final r = sanitizeAiQuestions([
        {
          'typeId': 2,
          'question': 'Warna favorit?',
          'options': ['Merah', 'Biru'],
        },
      ]);
      expect(r.hasErrors, isFalse);
      expect(r.questions.first['correctAnswer'], isNull);
      expect(r.questions.first['points'], isNull);
    });

    test('Checkbox tanpa kunci + dinilai → error', () {
      final r = sanitizeAiQuestions([
        {
          'typeId': 3,
          'question': 'Pilih yang benar',
          'points': 5,
          'options': ['A', 'B'],
        },
      ]);
      expect(r.hasErrors, isTrue);
    });

    test('Benar/Salah "benar" → "Benar"', () {
      final r = sanitizeAiQuestions([
        {'typeId': 5, 'question': 'Langit biru?', 'correctAnswer': 'benar'},
      ]);
      expect(r.hasErrors, isFalse);
      expect(r.questions.first['correctAnswer'], 'Benar');
    });

    test('Benar/Salah kunci ngawur + dinilai → error', () {
      final r = sanitizeAiQuestions([
        {'typeId': 5, 'question': 'Langit biru?', 'correctAnswer': 'Mungkin'},
      ]);
      expect(r.hasErrors, isTrue);
    });

    test('Esai bernilai tanpa kunci → error', () {
      final r = sanitizeAiQuestions([
        {'typeId': 1, 'question': 'Jelaskan fotosintesis', 'points': 10},
      ]);
      expect(r.hasErrors, isTrue);
    });

    test('Tanggal & waktu dipaksa non-scorable', () {
      final r = sanitizeAiQuestions([
        {
          'typeId': 4,
          'question': 'Kapan lahir?',
          'points': 10,
          'correctAnswer': 'besok',
        },
      ]);
      expect(r.hasErrors, isFalse);
      expect(r.questions.first['points'], isNull);
      expect(r.questions.first['correctAnswer'], isNull);
    });
  });
}
