import 'dart:convert';

import 'package:form_up/core/services/form_service.dart';

class AiFormContextService {
  /// Bangun blok konteks untuk AI dari daftar formId yang di-mention.
  /// Metadata ringan + skema JSON form (untuk analisis/edit struktur oleh AI).
  static Future<String> buildContext(List<int> formIds) async {
    if (formIds.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('<FORM_CONTEXT>');
    buffer.writeln('Berikut form yang di-mention user. Gunakan skema JSON di bawah untuk menganalisis atau mengedit form.');
    for (final id in formIds) {
      try {
        final form = await FormService.getForm(id);
        final settings = form['settings'] as Map<String, dynamic>? ?? {};
        final title = form['title'] as String? ?? 'Tanpa judul';
        final desc = form['description'] as String? ?? '';
        final formLink = form['formLink'] as String? ?? '';
        final status = form['status'] as String? ?? '';
        buffer.writeln();
        buffer.writeln('## Form #$id: $title (link: $formLink, status: $status)');
        if (desc.isNotEmpty) {
          final clean = _stripHtml(desc);
          buffer.writeln('Deskripsi: ${clean.length > 300 ? '${clean.substring(0, 300)}...' : clean}');
        }
        // Ambil questions
        try {
          final qs = await FormService.getQuestions(id);
          // Blok JSON skema — format machine-readable agar AI mudah mengedit struktur
          final schema = {
            'formId': id,
            'title': title,
            'description': desc,
            'settings': settings,
            'questions': [
              for (final q in qs)
                {
                  'id': q.id,
                  'typeId': q.typeId,
                  'question': _stripHtml(q.question),
                  'order': q.questionOrder,
                  if (q.isRequired != null) 'required': q.isRequired,
                  if (q.correctAnswer != null) 'correctAnswer': q.correctAnswer,
                  if (q.points != null) 'points': q.points,
                  'options': [for (final o in q.options) o.optionText],
                },
            ],
          };
          final encoder = JsonEncoder.withIndent('  ');
          buffer.writeln('Skema JSON:');
          buffer.writeln('```json');
          buffer.writeln(encoder.convert(schema));
          buffer.writeln('```');
          // Agregat jawaban responden (anonim) agar AI bisa menganalisis
          // pemahaman soal: distribusi opsi, % benar, contoh jawaban essay.
          try {
            final summary = await _buildResponseSummary(id, qs.map((q) => q.id).toSet());
            if (summary.isNotEmpty) {
              buffer.writeln('Agregat jawaban responden (anonim):');
              buffer.writeln(summary);
            }
          } catch (_) {}
        } catch (e) {
          buffer.writeln('Gagal ambil soal form $id: $e');
        }
      } catch (e) {
        buffer.writeln('Form #$id: gagal dimuat ($e)');
      }
    }
    buffer.writeln('</FORM_CONTEXT>');
    return buffer.toString();
  }

  /// Ringkasan semua form milik user (untuk prompt "list form saya" tanpa mention)
  static Future<String> buildAllFormsSummary({int limit = 20}) async {
    try {
      final forms = await FormService.getMyForms();
      if (forms.isEmpty) return '<FORM_LIST>Kosong - user belum punya form</FORM_LIST>';
      final sb = StringBuffer('<FORM_LIST>\n');
      for (var i = 0; i < forms.length && i < limit; i++) {
        final f = forms[i];
        sb.writeln('${i + 1}. #${f.id} ${f.title} [${f.status}] link:${f.formLink} respon:${f.responseCount}');
      }
      if (forms.length > limit) sb.writeln('... dan ${forms.length - limit} form lagi');
      sb.writeln('</FORM_LIST>');
      return sb.toString();
    } catch (e) {
      return '<FORM_LIST>Gagal memuat: $e</FORM_LIST>';
    }
  }

  static String _stripHtml(String s) {
    return s.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Ringkasan agregat jawaban per soal (tanpa identitas responden).
  /// Format per baris: Soal <id>: dijawab X, benar Y, opsi teratas [...],
  /// contoh essay [...]. Dibatasi agar prompt tetap ringan.
  static Future<String> _buildResponseSummary(int formId, Set<int> questionIds) async {
    final analytics = await FormService.getAnalytics(formId);
    if (analytics.respondents.isEmpty) return '';
    final answered = <int, int>{};
    final correct = <int, int>{};
    final optionHits = <int, Map<String, int>>{};
    final essaySamples = <int, List<String>>{};
    for (final r in analytics.respondents) {
      for (final a in r.answers) {
        if (!questionIds.contains(a.questionId)) continue;
        final text = (a.answerText ?? '').trim();
        if (text.isEmpty) continue;
        answered[a.questionId] = (answered[a.questionId] ?? 0) + 1;
        if (a.isCorrect == true) {
          correct[a.questionId] = (correct[a.questionId] ?? 0) + 1;
        }
        if (a.typeId == 1 || a.typeId == 4 || a.typeId == 5) {
          final list = essaySamples.putIfAbsent(a.questionId, () => []);
          if (list.length < 3) {
            final clean = _stripHtml(text);
            list.add(clean.length > 120 ? '${clean.substring(0, 120)}...' : clean);
          }
        } else {
          final map = optionHits.putIfAbsent(a.questionId, () => {});
          map[text] = (map[text] ?? 0) + 1;
        }
      }
    }
    if (answered.isEmpty) return '';
    final sb = StringBuffer();
    final ids = answered.keys.toList()..sort();
    for (final qid in ids) {
      final total = answered[qid]!;
      final ok = correct[qid] ?? 0;
      sb.write('Soal $qid: dijawab $total, benar $ok');
      final opts = optionHits[qid];
      if (opts != null && opts.isNotEmpty) {
        final top = opts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final shown = top.take(5).map((e) {
          final label = _stripHtml(e.key);
          final short = label.length > 40 ? '${label.substring(0, 40)}...' : label;
          return '"$short" (${e.value})';
        }).join(', ');
        sb.write(', opsi: [$shown]');
      }
      final samples = essaySamples[qid];
      if (samples != null && samples.isNotEmpty) {
        sb.write(', contoh: ["${samples.join('"; "')}"]');
      }
      sb.writeln();
    }
    return sb.toString().trimRight();
  }
}
