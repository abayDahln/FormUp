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
}
