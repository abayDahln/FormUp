import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Encode document Quill jadi string Delta JSON yang aman disimpan di kolom teks.
String encodeRichText(QuillController controller) {
  final plain = controller.document.toPlainText().trim();
  if (plain.isEmpty) return '';
  return jsonEncode(controller.document.toDelta().toJson());
}

/// Buat document dari string (Delta JSON, plain text lama, atau kosong).
Document richDocument(String? text) {
  final plain = text?.trim() ?? '';
  if (plain.isEmpty) return Document();
  if (!plain.startsWith('[')) return Document()..insert(0, plain);
  try {
    return Document.fromJson(jsonDecode(plain) as List);
  } catch (_) {
    return Document()..insert(0, plain);
  }
}

/// Ekstrak teks polos yang bersih dari konten (Delta JSON, HTML web, atau
/// plain text) untuk judul/sub-teks di kartu — hindari tampilan JSON mentah.
String richToPlainText(String? text) {
  final plain = text?.trim() ?? '';
  if (plain.isEmpty) return '';
  if (plain.startsWith('[')) {
    try {
      return Document.fromJson(jsonDecode(plain) as List)
          .toPlainText()
          .trim();
    } catch (_) {
      // ponytail: JSON valid tapi bukan Delta → jangan bocorkan JSON mentah.
      return '';
    }
  }
  return _stripHtml(plain).replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Controller Quill untuk editor / render read-only.
QuillController richTextController(String? text) => QuillController(
      document: richDocument(text),
      selection: const TextSelection.collapsed(offset: 0),
    );

/// Editor rich yang sedang fokus (controller + focus node) — dipakai
/// toolbar mengambang di atas keyboard supaya semua editor berbagi satu bar.
class ActiveRichEditor {
  final QuillController controller;
  final FocusNode focusNode;

  const ActiveRichEditor(this.controller, this.focusNode);
}

/// Notifier global: editor rich yang sedang fokus.
final ValueNotifier<ActiveRichEditor?> activeRichEditor = ValueNotifier(null);

/// Konfigurasi toolbar format: satu baris yang bisa digeser kiri/kanan.
QuillSimpleToolbarConfig richToolbarConfig({
  VoidCallback? afterButtonPressed,
  List<QuillToolbarCustomButtonOptions> customButtons = const [],
}) {
  return QuillSimpleToolbarConfig(
    multiRowsDisplay: false,
    showDividers: false,
    showFontFamily: true,
    showFontSize: true,
    showBoldButton: true,
    showItalicButton: true,
    showUnderLineButton: true,
    showStrikeThrough: true,
    showInlineCode: false,
    showColorButton: true,
    showBackgroundColorButton: true,
    showClearFormat: true,
    showAlignmentButtons: true,
    showHeaderStyle: true,
    showListNumbers: true,
    showListBullets: true,
    showListCheck: true,
    showCodeBlock: false,
    showQuote: false,
    showIndent: true,
    showLink: false,
    showUndo: true,
    showRedo: true,
    showSearchButton: false,
    showSubscript: false,
    showSuperscript: false,
    showLineHeightButton: false,
    customButtons: customButtons,
    buttonOptions: QuillSimpleToolbarButtonOptions(
      base: QuillToolbarBaseButtonOptions(
        afterButtonPressed: afterButtonPressed,
      ),
      fontFamily: QuillToolbarFontFamilyButtonOptions(
        items: const {
          'Arial': 'Arial',
          'Helvetica': 'Helvetica',
          'Times New Roman': 'Times New Roman',
          'Georgia': 'Georgia',
          'Courier New': 'Courier New',
          'Verdana': 'Verdana',
          'Tahoma': 'Tahoma',
          'Trebuchet MS': 'Trebuchet MS',
          'Impact': 'Impact',
          'Comic Sans MS': 'Comic Sans MS',
          'Garamond': 'Garamond',
          'Palatino Linotype': 'Palatino Linotype',
          'Inter': 'Inter',
          'Roboto': 'Roboto',
          'Open Sans': 'Open Sans',
          'Lato': 'Lato',
          'Montserrat': 'Montserrat',
          'Segoe UI': 'Segoe UI',
          'Merriweather': 'Merriweather',
          'Consolas': 'Consolas',
          'JetBrains Mono': 'JetBrains Mono',
          'Plus Jakarta Sans': 'PlusJakartaSans',
          'SF Pro Display': 'SF Pro Display',
          'SF Pro Text': 'SF Pro Text',
          'Fira Code': 'Fira Code',
          'Source Code Pro': 'Source Code Pro',
          'Poppins': 'Poppins',
          'Noto Sans': 'Noto Sans',
          'Ubuntu': 'Ubuntu',
          'DM Sans': 'DM Sans',
          'Clear': 'Clear',
        },
      ),
      fontSize: QuillToolbarFontSizeButtonOptions(
        items: const {
          '10': '10',
          '12': '12',
          '14': '14',
          '16': '16',
          '18': '18',
          '20': '20',
          '24': '24',
          '28': '28',
          'Hapus': '0',
        },
      ),
    ),
  );
}

/// Editor teks kaya (area teks saja, tanpa toolbar). Toolbar format dipakai
/// bersama lewat [FloatingRichToolbar] di atas keyboard saat editor fokus.
class RichTextEditor extends StatefulWidget {
  final QuillController controller;
  final String hint;
  final double minHeight;

  const RichTextEditor({
    super.key,
    required this.controller,
    this.hint = '',
    this.minHeight = 80,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  // ponytail: dipegang state agar tidak dibuat ulang per build (ScrollController
  // baru tiap rebuild bisa error "attached to multiple scroll views").
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    final active = activeRichEditor.value;
    if (_focusNode.hasFocus) {
      activeRichEditor.value = ActiveRichEditor(widget.controller, _focusNode);
      // ponytail: paksa keyboard muncul. QuillEditor kadang tidak memunculkan
      // soft keyboard di emulator yang dianggap punya hardware keyboard.
      SystemChannels.textInput.invokeMethod('TextInput.show').ignore();
    } else if (active?.controller == widget.controller) {
      activeRichEditor.value = null;
    }
  }

  @override
  void dispose() {
    final active = activeRichEditor.value;
    if (active?.controller == widget.controller) {
      activeRichEditor.value = null;
    }
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6E7979)),
      ),
      child: QuillEditor.basic(
        controller: widget.controller,
        focusNode: _focusNode,
        scrollController: _scrollController,
        config: QuillEditorConfig(
          autoFocus: false,
          expands: false,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          placeholder: widget.hint,
          scrollable: true,
          minHeight: widget.minHeight,
        ),
      ),
    );
  }
}

/// Toolbar format bersama yang mengambang di bagian bawah layar. Muncul hanya
/// saat ada editor rich yang fokus (tidak butuh keyboard terbuka — di emulator
/// tanpa soft keyboard toolbar tetap harus muncul). Taruh sebagai child Stack
/// di body screen.
class FloatingRichToolbar extends StatelessWidget {
  const FloatingRichToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActiveRichEditor?>(
      valueListenable: activeRichEditor,
      builder: (context, active, _) {
        if (active == null) {
          return const SizedBox.shrink();
        }
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Material(
            color: Colors.white,
            elevation: 6,
            child: SafeArea(
              top: false,
              child: QuillSimpleToolbar(
                controller: active.controller,
                config: richToolbarConfig(
                  afterButtonPressed: active.focusNode.requestFocus,
                  customButtons: [
                    QuillToolbarCustomButtonOptions(
                      icon: const Icon(Icons.functions, size: 18),
                      tooltip: 'Insert Math',
                      onPressed: () =>
                          _insertMath(context, active.controller),
                    ),
                    QuillToolbarCustomButtonOptions(
                      icon: const Icon(Icons.code, size: 18),
                      tooltip: 'Insert Code',
                      onPressed: () =>
                          _insertCode(context, active.controller),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Sisipkan teks ke posisi kursor editor Quill.
void _insertText(QuillController controller, String text) {
  final sel = controller.selection;
  final offset = sel.isValid ? sel.start : controller.document.length;
  controller.document.insert(offset, text);
  controller.updateSelection(
    TextSelection.collapsed(offset: offset + text.length),
    ChangeSource.local,
  );
}

/// Dialog insert rumus LaTeX ($$...$$) — quick symbol + preview.
Future<void> _insertMath(BuildContext context, QuillController controller) async {
  final focusScope = FocusScope.of(context);
  final formula = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _MathInsertSheet(),
  );
  if (formula == null || formula.trim().isEmpty) return;
  _insertText(controller, '\n\$\$${formula.trim()}\$\$\n');
  focusScope.requestFocus(FocusManager.instance.primaryFocus);
}

/// Dialog insert blok kode (```lang ... ```) — pilih bahasa + preview.
Future<void> _insertCode(BuildContext context, QuillController controller) async {
  final focusScope = FocusScope.of(context);
  final snippet = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _CodeInsertSheet(),
  );
  if (snippet == null || snippet.isEmpty) return;
  _insertText(controller, '\n$snippet\n');
  focusScope.requestFocus(FocusManager.instance.primaryFocus);
}

const _mathSymbols = <(String, String)>[
  (r'\frac{a}{b}', 'Fraction'),
  (r'\sqrt{x}', 'Sqrt'),
  (r'x^2', 'Power'),
  (r'x_1', 'Subscript'),
  (r'\sum_{i=1}^{n}', 'Sum'),
  (r'\int_{a}^{b}', 'Integral'),
  (r'\pm', '±'),
  (r'\infty', '∞'),
  (r'\pi', 'π'),
];

const _codeLanguages = <String>[
  'javascript', 'python', 'csharp', 'html', 'sql', 'java', 'cpp', 'json',
];

class _MathInsertSheet extends StatefulWidget {
  const _MathInsertSheet();

  @override
  State<_MathInsertSheet> createState() => _MathInsertSheetState();
}

class _MathInsertSheetState extends State<_MathInsertSheet> {
  final _controller = TextEditingController(
    text: r'\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formula = _controller.text.trim();
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Insert Math Formula',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (label, sym) in _mathSymbols)
                ActionChip(
                  label: Text(label),
                  onPressed: () {
                    setState(() => _controller.text += sym);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: r'LaTeX, e.g. \frac{-b \pm \sqrt{b^2-4ac}}{2a}',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          const Text(
            'Preview:',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: formula.isEmpty
                  ? const Text('…', style: TextStyle(fontSize: 16))
                  : Math.tex(
                      formula,
                      mathStyle: MathStyle.display,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, formula),
                  child: const Text('Insert'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodeInsertSheet extends StatefulWidget {
  const _CodeInsertSheet();

  @override
  State<_CodeInsertSheet> createState() => _CodeInsertSheetState();
}

class _CodeInsertSheetState extends State<_CodeInsertSheet> {
  final _controller = TextEditingController(
    text: 'function calculateSum(a, b) {\n    return a + b;\n}',
  );
  String _language = 'javascript';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _controller.text;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Insert Code Snippet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: const InputDecoration(
              labelText: 'Language',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final l in _codeLanguages)
                DropdownMenuItem(value: l, child: Text(l)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _language = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 6,
            minLines: 4,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Paste or type code here…',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          const Text(
            'Preview:',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: _CodeBlockView(language: _language, code: code),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, '```$_language\n$code\n```'),
                  child: const Text('Insert'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Satu blok paragraf hasil parsing Delta JSON: alignment + daftar span
/// (bisa berisi WidgetSpan untuk math inline) + teks mentah untuk deteksi
/// blok kode.
class _RichBlock {
  final TextAlign? align;
  final List<InlineSpan> spans;
  final String plain;

  const _RichBlock(this.align, this.spans, this.plain);
}

/// Blok kode bergaya StackOverflow: header bahasa + tombol salin + nomor baris.
class _CodeBlockView extends StatefulWidget {
  final String language;
  final String code;

  const _CodeBlockView({required this.language, required this.code});

  @override
  State<_CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends State<_CodeBlockView> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.code.split('\n');
    const codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      color: Colors.white,
      height: 1.5,
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const Icon(Icons.code, size: 14, color: Color(0xFF34D399)),
                const SizedBox(width: 6),
                Text(
                  widget.language.isEmpty ? 'code' : widget.language,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _copy,
                  child: Row(
                    children: [
                      Icon(
                        _copied ? Icons.check : Icons.copy,
                        size: 13,
                        color: _copied
                            ? const Color(0xFF34D399)
                            : Colors.white60,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _copied ? 'Copied!' : 'Copy',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  List.generate(lines.length, (i) => '${i + 1}').join('\n'),
                  style: codeStyle.copyWith(color: Colors.white24),
                ),
                const SizedBox(width: 10),
                Text(widget.code, style: codeStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget rumus matematika (flutter_math_fork).
Widget _mathWidget(String formula, {required bool display, TextStyle? style}) {
  final base = style ?? const TextStyle(fontSize: 13);
  return Math.tex(
    formula,
    mathStyle: display ? MathStyle.display : MathStyle.text,
    textStyle: base.copyWith(
      fontSize: display ? (style?.fontSize ?? 16) : (style?.fontSize ?? 13),
    ),
    onErrorFallback: (e) => Text(formula, style: base),
  );
}

/// Regex math: $$...$$ (display) atau $...$ (inline, tanpa newline).
final _mathRegex = RegExp(r'\$\$[^$]+\$\$|\$[^$\n]+?\$');

/// Split teks menjadi span, bagian math jadi WidgetSpan.
List<InlineSpan> _spansWithMath(String text, TextStyle? style) {
  final out = <InlineSpan>[];
  var last = 0;
  for (final m in _mathRegex.allMatches(text)) {
    if (m.start > last) {
      out.add(TextSpan(text: text.substring(last, m.start), style: style));
    }
    final seg = m.group(0)!;
    final display = seg.startsWith('\$\$');
    final formula = seg.substring(
      display ? 2 : 1,
      seg.length - (display ? 2 : 1),
    ).trim();
    out.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: _mathWidget(formula, display: display, style: style),
    ));
    last = m.end;
  }
  if (last < text.length) {
    out.add(TextSpan(text: text.substring(last), style: style));
  }
  return out;
}

/// Split spans Delta dengan deteksi math inline per span.
List<InlineSpan> _blockSpansWithMath(List<TextSpan> spans) {
  final out = <InlineSpan>[];
  for (final s in spans) {
    final t = s.text;
    if (t == null || !_mathRegex.hasMatch(t)) {
      out.add(s);
    } else {
      out.addAll(_spansWithMath(t, s.style));
    }
  }
  return out;
}

/// Render teks yang bisa berupa Delta JSON, plain text, atau HTML (dari web).
/// Mendukung math ($..$ / $$..$$) dan blok kode (```lang ... ```).
class RichTextView extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final String prefix;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const RichTextView({
    super.key,
    required this.text,
    this.style,
    this.prefix = '',
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    final delta = _deltaBlocks(trimmed);
    final blocks = delta ?? _plainBlocks(_stripHtml(trimmed));
    final widgets = _blocksToWidgets(blocks);

    // Konten hanya satu paragraf teks (tanpa math/kode) → hormati maxLines.
    final isPlainSingle =
        widgets.length == 1 && blocks.length == 1 && !_hasMathOrCode(blocks[0]);
    if (isPlainSingle) {
      return Text.rich(
        TextSpan(
          style: style,
          children: [
            if (prefix.isNotEmpty) TextSpan(text: prefix),
            ...blocks.first.spans,
          ],
        ),
        textAlign: blocks.first.align ?? textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  bool _hasMathOrCode(_RichBlock b) =>
      b.spans.any((s) => s is WidgetSpan) || b.plain.trim().startsWith('```');

  List<Widget> _blocksToWidgets(List<_RichBlock> blocks) {
    final widgets = <Widget>[];
    var first = true;
    var i = 0;
    while (i < blocks.length) {
      final b = blocks[i];
      final t = b.plain.trim();

      // Blok kode yang dihasilkan _plainBlocks sudah berupa WidgetSpan.
      if (t.startsWith('```')) {
        widgets.add(Text.rich(
          TextSpan(style: style, children: b.spans),
        ));
        i++;
        continue;
      }

      // Fence di dalam Delta (paragraf "```lang" ... "```").
      final fence = RegExp(r'^```([a-zA-Z0-9_#-]*)$').firstMatch(t);
      if (fence != null) {
        final lang = fence.group(1) ?? '';
        final codeLines = <String>[];
        i++;
        while (i < blocks.length) {
          final line = blocks[i].plain.trimRight();
          if (line.startsWith('```')) break;
          codeLines.add(blocks[i].plain);
          i++;
        }
        if (i < blocks.length && blocks[i].plain.trim().startsWith('```')) {
          i++;
        }
        widgets.add(_CodeBlockView(
          language: lang,
          code: codeLines.join('\n'),
        ));
        continue;
      }

      // Blok math display $$...$$.
      final math = RegExp(r'^\$\$([\s\S]+?)\$\$$').firstMatch(t);
      if (math != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _mathWidget(math.group(1)!.trim(), display: true, style: style),
          ),
        ));
        i++;
        continue;
      }

      widgets.add(Text.rich(
        TextSpan(
          style: style,
          children: [
            if (first && prefix.isNotEmpty) TextSpan(text: prefix),
            ...b.spans,
          ],
        ),
        textAlign: b.align ?? textAlign,
      ));
      first = false;
      i++;
    }
    return widgets;
  }
}

/// Hapus tag HTML dasar, sisakan isi. Dipakai untuk konten web (Summernote).
String _stripHtml(String raw) {
  var s = raw
      .replaceAll('<br>', '\n')
      .replaceAll('<br/>', '\n')
      .replaceAll('<br />', '\n')
      .replaceAll('</p>', '\n')
      .replaceAll('</div>', '\n')
      .replaceAll('</h1>', '\n')
      .replaceAll('</h2>', '\n')
      .replaceAll('</h3>', '\n')
      .replaceAll('</li>', '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return s.trim();
}

/// Pecah plain text menjadi blok (paragraf / math / code fence).
List<_RichBlock> _plainBlocks(String text) {
  final blocks = <_RichBlock>[];
  var buffer = StringBuffer();
  String? fenceLang;
  final codeLines = <String>[];

  void flushText() {
    final t = buffer.toString();
    buffer = StringBuffer();
    if (t.trim().isEmpty) return;
    blocks.add(_RichBlock(null, _spansWithMath(t, null), t));
  }

  for (final line in text.split('\n')) {
    final t = line.trim();
    if (fenceLang != null) {
      if (t.startsWith('```')) {
        blocks.add(_RichBlock(
          null,
          [
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: _CodeBlockView(
                language: fenceLang,
                code: codeLines.join('\n'),
              ),
            ),
          ],
          '```',
        ));
        fenceLang = null;
        codeLines.clear();
      } else {
        codeLines.add(line);
      }
      continue;
    }
    final fence = RegExp(r'^```([a-zA-Z0-9_#-]*)$').firstMatch(t);
    if (fence != null) {
      flushText();
      fenceLang = fence.group(1) ?? '';
      continue;
    }
    buffer.writeln(line);
  }
  flushText();
  if (fenceLang != null && codeLines.isNotEmpty) {
    blocks.add(_RichBlock(
      null,
      [
        WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: _CodeBlockView(
            language: fenceLang,
            code: codeLines.join('\n'),
          ),
        ),
      ],
      '```',
    ));
  }
  return blocks;
}

/// Ubah Delta JSON jadi daftar blok paragraf (list, header, alignment).
/// Mengembalikan null jika [raw] bukan Delta JSON (plain text).
List<_RichBlock>? _deltaBlocks(String raw) {
  if (!raw.startsWith('[')) return null;
  final List ops;
  try {
    ops = jsonDecode(raw) as List;
  } catch (_) {
    return null;
  }

  final blocks = <_RichBlock>[];
  var current = <TextSpan>[];
  var buffer = StringBuffer();
  var orderedIndex = 0;
  // Atribut level blok dibawa oleh op newline di akhir paragraf.
  var listType = '';
  var blockAlign = '';
  var blockHeader = 0;

  void flush() {
    final spans = <TextSpan>[];
    if (listType.isNotEmpty) {
      spans.add(TextSpan(
        text: switch (listType) {
          'ordered' => '${++orderedIndex}. ',
          'bullet' => '\u2022 ',
          'checked' => '\u2611 ',
          'unchecked' => '\u2610 ',
          _ => '',
        },
      ));
    }
    final headerStyle = _headerStyle(blockHeader);
    if (headerStyle != null && current.isNotEmpty) {
      current = [
        for (final s in current)
          TextSpan(
            text: s.text,
            style: s.style == null ? headerStyle : s.style!.merge(headerStyle),
          ),
      ];
    }
    spans.addAll(current);
    if (spans.isNotEmpty) {
      blocks.add(_RichBlock(
        _alignOf(blockAlign),
        _blockSpansWithMath(spans),
        buffer.toString(),
      ));
    }
    buffer = StringBuffer();
    current = [];
    if (listType != 'ordered') orderedIndex = 0;
    listType = '';
    blockAlign = '';
    blockHeader = 0;
  }

  for (final op in ops) {
    // ponytail: JSON valid tapi bukan Delta (mis. ["a","b"] / [123]) jangan
    // sampai crash — skip op yang bukan Map.
    if (op is! Map) continue;
    final insert = op['insert'];
    if (insert is! String) continue;
    final rawAttr = op['attributes'];
    final attr = rawAttr is Map
        ? rawAttr.cast<String, dynamic>()
        : const <String, dynamic>{};
    final style = _styleFrom(attr);
    final parts = insert.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        current.add(TextSpan(text: parts[i], style: style));
        buffer.write(parts[i]);
      }
      if (i < parts.length - 1) {
        listType = attr['list'] as String? ?? listType;
        blockAlign = attr['align'] as String? ?? blockAlign;
        final header = attr['header'];
        if (header is int) blockHeader = header;
        flush();
      }
    }
  }
  flush();
  return blocks;
}

TextAlign? _alignOf(String align) => switch (align) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      'justify' => TextAlign.justify,
      _ => null,
    };

TextStyle? _headerStyle(int header) {
  if (header <= 0) return null;
  return TextStyle(
    fontSize: switch (header) {
      1 => 24.0,
      2 => 21.0,
      3 => 18.0,
      4 => 16.0,
      5 => 14.0,
      _ => 13.0,
    },
    fontWeight: FontWeight.bold,
  );
}

TextStyle? _sizeStyle(dynamic size) {
  if (size == null) return null;
  final s = size.toString();
  return switch (s) {
    'small' => const TextStyle(fontSize: 10),
    'large' => const TextStyle(fontSize: 18),
    'huge' => const TextStyle(fontSize: 22),
    'normal' => null,
    _ => _numericFontSize(s),
  };
}

TextStyle? _numericFontSize(String s) {
  final v = double.tryParse(s);
  if (v == null || v <= 0) return null;
  return TextStyle(fontSize: v);
}

TextStyle? _styleFrom(Map<String, dynamic> attr) {
  TextStyle? style;
  if (attr['bold'] == true) {
    style = const TextStyle().copyWith(fontWeight: FontWeight.bold);
  }
  if (attr['italic'] == true) {
    style = (style ?? const TextStyle()).copyWith(fontStyle: FontStyle.italic);
  }
  final underline = attr['underline'] == true;
  final strike = attr['strike'] == true;
  if (underline || strike) {
    style = (style ?? const TextStyle()).copyWith(
      decoration: TextDecoration.combine([
        if (underline) TextDecoration.underline,
        if (strike) TextDecoration.lineThrough,
      ]),
    );
  }
  final color = attr['color'] as String?;
  if (color != null) {
    style = (style ?? const TextStyle()).copyWith(color: _parseColor(color));
  }
  final background = attr['background'] as String?;
  if (background != null) {
    style = (style ?? const TextStyle())
        .copyWith(backgroundColor: _parseColor(background));
  }
  final sizeStyle = _sizeStyle(attr['size']);
  if (sizeStyle != null) {
    style = (style ?? const TextStyle()).merge(sizeStyle);
  }
  final font = attr['font'] as String?;
  if (font != null && font.isNotEmpty) {
    style = (style ?? const TextStyle()).copyWith(fontFamily: font);
  }
  final header = attr['header'];
  if (header is int) {
    final hs = _headerStyle(header);
    if (hs != null) style = (style ?? const TextStyle()).merge(hs);
  }
  return style;
}

Color _parseColor(String hex) {
  final h = hex.replaceAll('#', '');
  final value = int.tryParse(h, radix: 16) ?? 0x000000;
  return h.length == 6 ? Color(0xFF000000 | value) : Color(value);
}
