import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

void main() {
  group('richToPlainText', () {
    test('mengekstrak teks dari Delta JSON', () {
      final delta = '[{"insert": "Inggris\\n"}, {"insert": "12A\\n"}]';
      expect(richToPlainText(delta), contains('Inggris'));
      expect(richToPlainText(delta), contains('12A'));
    });

    test('mengembalikan plain text apa adanya', () {
      expect(richToPlainText('  Ulangan Bahasa Inggris  '), 'Ulangan Bahasa Inggris');
    });

    test('menghapus tag HTML (konten dari web)', () {
      expect(
        richToPlainText('<p>Formulir <b>Pendaftaran</b> Siswa</p>'),
        'Formulir Pendaftaran Siswa',
      );
    });

    test('tidak bocorkan JSON mentah saat Delta tidak valid', () {
      expect(richToPlainText('[123]'), '');
      expect(richToPlainText('["a","b"]'), '');
      expect(richToPlainText(''), '');
    });
  });

  testWidgets('RichTextView menampilkan tag HTML dalam blok kode apa adanya',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RichTextView(
          text:
              '<pre><code class="language-html"><div class="box">Hi</div></code></pre>',
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    // Tag harus tampil sebagai teks kode, bukan dimakan sebagai wysiwyg.
    expect(find.textContaining('<div'), findsWidgets);
  });

  testWidgets('RichTextView tidak crash pada array JSON non-Delta',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RichTextView(text: '["a","b"]')),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RichTextView merender math penanda dolar tanpa error',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: const [
            RichTextView(text: 'Rumus \$x^2\$ inline'),
            RichTextView(text: 'Display:\n\$\$\\frac{1}{2}\$\$'),
          ],
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}

