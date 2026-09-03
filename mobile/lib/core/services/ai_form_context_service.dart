import 'package:form_up/core/services/form_service.dart';

class AiFormContextService {
  /// Bangun blok konteks untuk AI dari daftar formId yang di-mention.
  /// Hanya ambil metadata ringan (judul, deskripsi, jumlah soal, tipe) + daftar pertanyaan ringkas.
  static Future<String> buildContext(List<int> formIds) async {
    if (formIds.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('<FORM_CONTEXT>');
    for (final id in formIds) {
      try {
        final form = await FormService.getForm(id);
        final settings = form['settings'] as Map<String, dynamic>?;
        final title = form['title'] as String? ?? 'Tanpa judul';
        final desc = form['description'] as String? ?? '';
        final formLink = form['formLink'] as String? ?? '';
        final status = form['status'] as String? ?? '';
        buffer.writeln('Form #$id: $title (link: $formLink, status: $status)');
        if (desc.isNotEmpty) buffer.writeln('Deskripsi: ${_stripHtml(desc).substring(0, desc.length > 300 ? 300 : desc.length)}');
        if (settings != null) {
          buffer.writeln('Settings: ${settings.toString()}');
        }
        // Ambil questions
        try {
          final qs = await FormService.getQuestions(id);
          buffer.writeln('Jumlah soal: ${qs.length}');
          for (var i = 0; i < qs.length && i < 15; i++) {
            final q = qs[i];
            final qText = _stripHtml(q.question);
            final short = qText.length > 80 ? '${qText.substring(0, 80)}...' : qText;
            buffer.writeln('  ${i + 1}. [type:${q.typeId}] $short ${q.options.isNotEmpty ? "opsi:${q.options.map((o) => o.optionText).join(", ")}" : ""}');
          }
          if (qs.length > 15) buffer.writeln('  ... dan ${qs.length - 15} soal lagi');
        } catch (_) {
          buffer.writeln('Gagal ambil soal form $id');
        }
        buffer.writeln('---');
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
