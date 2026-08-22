import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

void main() {
  test('encodeRichText menghasilkan HTML, richDocument membacanya balik', () {
    final controller = QuillController(
      document: richDocument(''),
      selection: const TextSelection.collapsed(offset: 0),
    );
    controller.document.insert(0, 'Halo dunia');
    controller.formatText(0, 4, Attribute.bold);

    final html = encodeRichText(controller);
    expect(html, contains('<b>Halo</b>'));

    final reloaded = richDocument(html);
    expect(reloaded.toPlainText().trim(), 'Halo dunia');

    final ops = reloaded.toDelta().toList();
    final boldOp = ops.firstWhere((o) => o.data == 'Halo');
    expect(boldOp.attributes?['bold'], isTrue);
  });

  test('richDocument membaca HTML web gaya Summernote', () {
    final doc = richDocument(
      '<h1>Judul</h1><p>Halo <b>bold</b> <i>italic</i> <u>under</u> <s>strike</s></p>'
      '<ul><li>satu</li><li>dua</li></ul>',
    );
    final plain = doc.toPlainText();
    expect(plain, contains('Judul'));
    expect(plain, contains('Halo bold italic under strike'));
    expect(plain, contains('satu'));
    expect(plain, contains('dua'));

    final ops = doc.toDelta().toList();
    final bold = ops.firstWhere((o) => o.data == 'bold');
    expect(bold.attributes?['bold'], isTrue);
    final italic = ops.firstWhere((o) => o.data == 'italic');
    expect(italic.attributes?['italic'], isTrue);
    final underline = ops.firstWhere((o) => o.data == 'under');
    expect(underline.attributes?['underline'], isTrue);
    final strike = ops.firstWhere((o) => o.data == 'strike');
    expect(strike.attributes?['strike'], isTrue);
  });

  test('richDocument membaca warna/size dari span style', () {
    final doc = richDocument(
      '<p><span style="color: rgb(255, 0, 0); font-size: 18px;">merah</span></p>',
    );
    final ops = doc.toDelta().toList();
    final run = ops.firstWhere((o) => o.data == 'merah');
    expect(run.attributes?['color'], '#ff0000');
    expect(run.attributes?['size'], 18);
  });

  test('richDocument membaca blok kode <pre><code> sebagai fence', () {
    final doc = richDocument(
      '<pre><code class="language-python">print(1)\nprint(2)</code></pre>',
    );
    expect(doc.toPlainText(), contains('```python'));
    expect(doc.toPlainText(), contains('print(1)'));
    expect(doc.toPlainText(), contains('print(2)'));
  });

  test('encodeRichText kosong untuk konten polos', () {
    final controller = QuillController(
      document: richDocument('   '),
      selection: const TextSelection.collapsed(offset: 0),
    );
    expect(encodeRichText(controller), '');
  });
}

