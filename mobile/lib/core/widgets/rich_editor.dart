import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Delta → HTML web
String encodeRichText(QuillController controller) {
  final plain = controller.document.toPlainText().trim();
  if (plain.isEmpty) return '';
  return _deltaToHtml(controller.document.toDelta().toJson());
}

/// Buat document
Document richDocument(String? text) {
  final plain = text?.trim() ?? '';
  if (plain.isEmpty) return Document();
  try {
    if (plain.startsWith('<')) {
      return Document.fromJson(_htmlToDeltaOps(plain));
    }
    if (plain.startsWith('[')) {
      return Document.fromJson(jsonDecode(plain) as List);
    }
  } catch (_) {
    return Document()..insert(0, plain);
  }
  return Document()..insert(0, plain);
}

String richToPlainText(String? text) {
  final plain = text?.trim() ?? '';
  if (plain.isEmpty) return '';
  if (plain.startsWith('[')) {
    try {
      return Document.fromJson(jsonDecode(plain) as List)
          .toPlainText()
          .trim();
    } catch (_) {
      // ponytail: non-Delta jangan crash
      return '';
    }
  }
  return _stripHtml(plain).replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

QuillController richTextController(String? text) => QuillController(
      document: richDocument(text),
      selection: const TextSelection.collapsed(offset: 0),
    );

String _deltaToHtml(List<dynamic> ops) {
  final lines = <_OutLine>[];
  var runs = <_OutRun>[];
  var blockAttrs = const <String, dynamic>{};

  void flushLine() {
    lines.add(_OutLine(runs, blockAttrs));
    runs = [];
    blockAttrs = const {};
  }

  for (final op in ops) {
    if (op is! Map) continue;
    final insert = op['insert'];
    final attrs = op['attributes'] is Map
        ? (op['attributes'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    if (insert is String) {
      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          runs.add(_OutRun(parts[i], attrs));
        }
        if (i < parts.length - 1) {
          blockAttrs = attrs;
          flushLine();
        }
      }
    } else if (insert is Map) {
      final image = insert['image'];
      if (image is String) runs.add(_OutRun('', const {}, imageUrl: image));
    }
  }
  if (runs.isNotEmpty || lines.isEmpty) flushLine();

  final sb = StringBuffer();
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final plain = line.plain.trim();

    final fence = RegExp(r'^```([a-zA-Z0-9_#-]*)').firstMatch(plain);
    if (fence != null) {
      final lang = fence.group(1) ?? '';
      final codeLines = <String>[];
      i++;
      while (i < lines.length) {
        final p = lines[i].plain.trimRight();
        if (p.trim().startsWith('```')) {
          i++;
          break;
        }
        codeLines.add(p);
        i++;
      }
      sb.write(
          '<pre><code class="language-${lang.isEmpty ? 'code' : lang}">${_escapeHtml(codeLines.join('\n'))}</code></pre>');
      continue;
    }

    final lt = line.blockAttrs['list'];
    if (lt == 'ordered' || lt == 'bullet' || lt == 'alpha') {
      final isOrdered = lt == 'ordered' || lt == 'alpha';
      final tag = isOrdered ? 'ol' : 'ul';
      final typeAttr = lt == 'alpha' ? ' type="a"' : '';
      sb.write('<$tag$typeAttr>');
      while (i < lines.length && lines[i].blockAttrs['list'] == lt) {
        sb.write('<li>${_inlineHtml(lines[i].runs)}</li>');
        i++;
      }
      sb.write('</$tag>');
      continue;
    }

    final header = line.blockAttrs['header'];
    final align = line.blockAttrs['align'];
    final styleAttr = align is String && align.isNotEmpty
        ? ' style="text-align: $align"'
        : '';
    final inner = _inlineHtml(line.runs);
    if (header is int && header >= 1 && header <= 6) {
      sb.write('<h$header$styleAttr>$inner</h$header>');
    } else {
      sb.write('<p$styleAttr>$inner</p>');
    }
    i++;
  }
  return sb.toString();
}

String _inlineHtml(List<_OutRun> runs) {
  return runs.map(_runToHtml).join();
}

String _runToHtml(_OutRun r) {
  if (r.imageUrl != null) return '<img src="${r.imageUrl}" />';
  var html = _escapeHtml(r.text);
  final a = r.attrs;
  var spanStyles = '';
  if (a['color'] is String) spanStyles += 'color: ${a['color']};';
  if (a['background'] is String) {
    spanStyles += 'background-color: ${a['background']};';
  }
  if (a['font'] is String) spanStyles += 'font-family: ${a['font']};';
  final size = a['size'];
  if (size != null) {
    spanStyles += switch (size.toString()) {
      'small' => 'font-size: 12px;',
      'large' => 'font-size: 18px;',
      'huge' => 'font-size: 24px;',
      'normal' => '',
      _ => 'font-size: ${size}px;',
    };
  }
  if (spanStyles.isNotEmpty) html = '<span style="$spanStyles">$html</span>';
  final link = a['link'];
  if (link is String && link.isNotEmpty) html = '<a href="$link">$html</a>';
  if (a['bold'] == true) html = '<b>$html</b>';
  if (a['italic'] == true) html = '<i>$html</i>';
  if (a['underline'] == true) html = '<u>$html</u>';
  if (a['strike'] == true) html = '<s>$html</s>';
  return html;
}

// ponytail: & tak di-escape; < > tetap
String _escapeHtml(String s) =>
    s.replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// HTML → Delta
List<Map> _htmlToDeltaOps(String html) {
  final tokens = _tokenizeHtml(html);
  final ops = <Map>[];
  final inlineStack = <Map<String, dynamic>>[];
  var listType = '';
  var align = '';
  var header = 0;
  var codeBuffer = StringBuffer();
  var codeLang = '';
  var inCode = false;
  var pendingRuns = <(String, Map<String, dynamic>)>[];

  void flushCode() {
    if (codeBuffer.isEmpty) return;
    final lang = codeLang.isEmpty ? '' : codeLang;
    final code = codeBuffer.toString();
    ops.add({
      'insert': '```${lang.isEmpty ? '' : lang}\n$code\n```',
    });
    ops.add({'insert': '\n'});
    codeBuffer = StringBuffer();
    codeLang = '';
  }

  void flushLine() {
    if (inCode) return;
    final blockAttrs = <String, dynamic>{};
    if (listType.isNotEmpty) blockAttrs['list'] = listType;
    if (align.isNotEmpty) blockAttrs['align'] = align;
    if (header > 0) blockAttrs['header'] = header;
    if (pendingRuns.isEmpty && blockAttrs.isEmpty) return;
    for (final (t, a) in pendingRuns) {
      ops.add(a.isEmpty ? {'insert': t} : {'insert': t, 'attributes': a});
    }
    pendingRuns = [];
    ops.add(blockAttrs.isEmpty
        ? {'insert': '\n'}
        : {'insert': '\n', 'attributes': blockAttrs});
  }

  for (final t in tokens) {
    if (t.text != null) {
      if (inCode) {
        codeBuffer.write(_unescapeHtml(t.text!));
      } else {
        final txt = _unescapeHtml(t.text!);
        if (txt.isNotEmpty) pendingRuns.add((txt, _mergeInline(inlineStack)));
      }
      continue;
    }

    final name = t.tagName!;
    if (t.closing) {
      switch (name) {
        case 'p':
        case 'div':
        case 'li':
          flushLine();
          align = '';
          break;
        case 'blockquote':
        case 'pre':
          flushCode();
          inCode = false;
          codeLang = '';
          flushLine();
          break;
        case 'h1':
        case 'h2':
        case 'h3':
        case 'h4':
        case 'h5':
        case 'h6':
          flushLine();
          header = 0;
          break;
        case 'ul':
        case 'ol':
          listType = '';
          break;
        case 'code':
          if (!inCode && inlineStack.isNotEmpty) inlineStack.removeLast();
          break;
        default:
          if (inlineStack.isNotEmpty) inlineStack.removeLast();
      }
      continue;
    }

    switch (name) {
      case 'p':
      case 'div':
      case 'section':
        flushLine();
        align = _styleAlign(t.attrs['style']);
        break;
      case 'br':
        flushLine();
        break;
      case 'ul':
        listType = 'bullet';
        break;
      case 'ol':
        listType = t.attrs['type'] == 'a' ? 'alpha' : 'ordered';
        break;
      case 'li':
        flushLine();
        break;
      case 'blockquote':
        flushLine();
        break;
      case 'pre':
        flushLine();
        inCode = true;
        codeLang = '';
        break;
      case 'code':
        if (inCode) {
          final cls = t.attrs['class'] ?? '';
          final m = RegExp(r'language-([a-zA-Z0-9_#-]+)').firstMatch(cls);
          if (m != null) codeLang = m.group(1)!;
        } else {
          inlineStack.add(const {});
        }
        break;
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        flushLine();
        header = int.parse(name.substring(1));
        break;
      case 'b':
      case 'strong':
        inlineStack.add(const {'bold': true});
        break;
      case 'i':
      case 'em':
        inlineStack.add(const {'italic': true});
        break;
      case 'u':
        inlineStack.add(const {'underline': true});
        break;
      case 's':
      case 'strike':
        inlineStack.add(const {'strike': true});
        break;
      case 'span':
        inlineStack.add(_spanInlineAttrs(t.attrs['style']));
        break;
      case 'a':
        inlineStack.add({'link': t.attrs['href'] ?? ''});
        break;
      case 'font':
        inlineStack.add(_fontInlineAttrs(t.attrs));
        break;
      case 'img':
        // ponytail: gambar HTML diabaikan
        break;
      case 'script':
      case 'style':
      case 'head':
      case 'meta':
      case 'link':
      default:
        inlineStack.add(const {});
    }
  }
  if (inCode) {
    flushCode();
    inCode = false;
  }
  flushLine();
  if (ops.isEmpty) ops.add({'insert': '\n'});
  return ops;
}

Map<String, dynamic> _mergeInline(List<Map<String, dynamic>> stack) {
  final merged = <String, dynamic>{};
  for (final m in stack) {
    merged.addAll(m);
  }
  return merged;
}

String _styleAlign(String? style) {
  if (style == null) return '';
  for (final decl in style.split(';')) {
    final kv = decl.split(':');
    if (kv.length < 2) continue;
    if (kv[0].trim().toLowerCase() == 'text-align') {
      final v = kv.sublist(1).join(':').trim().toLowerCase();
      if (v == 'center' || v == 'right' || v == 'justify') return v;
    }
  }
  return '';
}

Map<String, dynamic> _spanInlineAttrs(String? style) {
  final attrs = <String, dynamic>{};
  if (style == null) return attrs;
  for (final decl in style.split(';')) {
    final kv = decl.split(':');
    if (kv.length < 2) continue;
    final k = kv[0].trim().toLowerCase();
    final v = kv.sublist(1).join(':').trim();
    switch (k) {
      case 'color':
        final c = _normalizeColor(v);
        if (c.isNotEmpty) attrs['color'] = c;
      case 'background-color':
      case 'background':
        final c = _normalizeColor(v);
        if (c.isNotEmpty) attrs['background'] = c;
      case 'font-size':
        final px = double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), ''));
        if (px != null && px > 0) attrs['size'] = px.round();
      case 'font-family':
        final f = v.replaceAll('"', '').replaceAll("'", '');
        if (f.isNotEmpty) attrs['font'] = f;
      case 'font-weight':
        if (v == 'bold' || v == '700' || v == '800' || v == '900') {
          attrs['bold'] = true;
        }
      case 'font-style':
        if (v == 'italic') attrs['italic'] = true;
      case 'text-decoration':
        if (v.contains('underline')) attrs['underline'] = true;
        if (v.contains('line-through')) attrs['strike'] = true;
    }
  }
  return attrs;
}

Map<String, dynamic> _fontInlineAttrs(Map<String, String> tag) {
  final attrs = <String, dynamic>{};
  final color = tag['color'];
  if (color != null) {
    final c = _normalizeColor(color);
    if (c.isNotEmpty) attrs['color'] = c;
  }
  final size = tag['size'];
  if (size != null) {
    final v = int.tryParse(size.replaceAll(RegExp(r'[^0-9]'), ''));
    if (v != null && v > 0) attrs['size'] = v;
  }
  final face = tag['face'];
  if (face != null && face.isNotEmpty) attrs['font'] = face;
  return attrs;
}

String _normalizeColor(String value) {
  final rgb = RegExp(r'rgba?\((\d+),\s*(\d+),\s*(\d+)').firstMatch(value);
  if (rgb != null) {
    final r = int.parse(rgb.group(1)!);
    final g = int.parse(rgb.group(2)!);
    final b = int.parse(rgb.group(3)!);
    return '#${(r << 16 | g << 8 | b).toRadixString(16).padLeft(6, '0')}';
  }
  return RegExp(r'#[0-9a-fA-F]{3,8}').firstMatch(value)?.group(0) ?? '';
}

String _unescapeHtml(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

List<_HtmlToken> _tokenizeHtml(String html) {
  final tokens = <_HtmlToken>[];
  final re = RegExp(r'<[^>]*>');
  var last = 0;
  for (final m in re.allMatches(html)) {
    if (m.start > last) tokens.add(_HtmlToken.text(html.substring(last, m.start)));
    final tagStr = m.group(0)!;
    final closing = tagStr.startsWith('</');
    final selfClose = tagStr.endsWith('/>');
    final content = tagStr
        .substring(closing ? 2 : 1, tagStr.length - (selfClose ? 2 : 1))
        .trim();
    final nameMatch = RegExp(r'^[a-zA-Z0-9]+').firstMatch(content);
    final name = nameMatch == null ? '' : nameMatch.group(0)!.toLowerCase();
    final attrs = <String, String>{};
    final attrRe = RegExp(
      r'''([a-zA-Z_:][a-zA-Z0-9_:.\-]*)(?:\s*=\s*("([^"]*)"|'([^']*)'|([^\s>]+)))?''',
    );
    for (final am in attrRe.allMatches(content)) {
      final key = am.group(1)?.toLowerCase();
      if (key == null || key == name) continue;
      attrs[key] = am.group(3) ?? am.group(4) ?? am.group(5) ?? '';
    }
    tokens.add(_HtmlToken.tag(name, closing, attrs));
    last = m.end;
  }
  if (last < html.length) tokens.add(_HtmlToken.text(html.substring(last)));
  return tokens;
}

class _HtmlToken {
  final String? text;
  final String? tagName;
  final bool closing;
  final Map<String, String> attrs;

  _HtmlToken.text(String this.text)
      : tagName = null,
        closing = false,
        attrs = const {};

  _HtmlToken.tag(String this.tagName, this.closing, this.attrs)
      : text = null;
}

class _OutLine {
  final List<_OutRun> runs;
  final Map<String, dynamic> blockAttrs;

  _OutLine(this.runs, this.blockAttrs);

  String get plain => runs.map((r) => r.text).join();
}

class _OutRun {
  final String text;
  final Map<String, dynamic> attrs;
  final String? imageUrl;

  _OutRun(this.text, this.attrs, {this.imageUrl});
}
class ActiveRichEditor {
  final QuillController controller;
  final FocusNode focusNode;

  const ActiveRichEditor(this.controller, this.focusNode);
}

final ValueNotifier<ActiveRichEditor?> activeRichEditor = ValueNotifier(null);

/// Konfigurasi toolbar format
QuillSimpleToolbarConfig richToolbarConfig({
  VoidCallback? afterButtonPressed,
  List<QuillToolbarCustomButtonOptions> customButtons = const [],
}) {
  return QuillSimpleToolbarConfig(
    // ponytail: 2 baris (Wrap) agar horizontal compact tapi toolbar lebih tinggi
    multiRowsDisplay: true,
    toolbarRunSpacing: 2,
    showDividers: false,
    showFontFamily: false,
    showFontSize: false, // kontrol ukuran font kustom (_FontSizeControl)
    showBoldButton: true,
    showItalicButton: true,
    showUnderLineButton: true,
    showStrikeThrough: true,
    showInlineCode: false,
    showColorButton: true,
    showBackgroundColorButton: true,
    showClearFormat: true,
    showAlignmentButtons: false, // dropdown perataan kustom
    showHeaderStyle: false,
    showListNumbers: false, // dropdown daftar kustom
    showListBullets: false,
    showListCheck: false,
    showCodeBlock: false,
    showQuote: false,
    showIndent: false, // indent tidak diperlukan
    showLink: false,
    showUndo: true,
    showRedo: true,
    showSearchButton: false,
    showSubscript: false,
    showSuperscript: false,
    showLineHeightButton: false,
    customButtons: [
      ...customButtons,
      QuillToolbarCustomButtonOptions(
        tooltip: 'Perataan',
        childBuilder: (dynamic _, dynamic extra) => _ToolbarAlignDropdown(
          controller: extra.controller as QuillController,
          afterPressed: afterButtonPressed,
        ),
      ),
      QuillToolbarCustomButtonOptions(
        tooltip: 'Daftar',
        childBuilder: (dynamic _, dynamic extra) => _ToolbarListDropdown(
          controller: extra.controller as QuillController,
          afterPressed: afterButtonPressed,
        ),
      ),
      QuillToolbarCustomButtonOptions(
        tooltip: 'Ukuran font',
        childBuilder: (dynamic _, dynamic extra) => _FontSizeControl(
          controller: extra.controller as QuillController,
          afterPressed: afterButtonPressed,
        ),
      ),
    ],
    buttonOptions: QuillSimpleToolbarButtonOptions(
      base: QuillToolbarBaseButtonOptions(
        afterButtonPressed: afterButtonPressed,
      ),
    ),
  );
}

/// Batas ukuran font yang boleh di-input manual (agar layout tidak rusak).
const double kMinFontSize = 8;
const double kMaxFontSize = 48;

/// Tombol dropdown perataan (left/center/right/justify).
class _ToolbarAlignDropdown extends StatelessWidget {
  final QuillController controller;
  final VoidCallback? afterPressed;

  const _ToolbarAlignDropdown({required this.controller, this.afterPressed});

  @override
  Widget build(BuildContext context) {
    return _MenuToolbarButton(
      controller: controller,
      tooltip: 'Perataan',
      afterPressed: afterPressed,
      iconBuilder: (c) {
        final align = c
            .getSelectionStyle()
            .attributes[Attribute.align.key]
            ?.value;
        return Icon(
          switch (align) {
            'center' => Icons.format_align_center,
            'right' => Icons.format_align_right,
            'justify' => Icons.format_align_justify,
            _ => Icons.format_align_left,
          },
          size: 15,
        );
      },
      menuBuilder: (c) => [
        _alignMenuItem(Icons.format_align_left, 'Kiri', Attribute.leftAlignment, c),
        _alignMenuItem(Icons.format_align_center, 'Tengah', Attribute.centerAlignment, c),
        _alignMenuItem(Icons.format_align_right, 'Kanan', Attribute.rightAlignment, c),
        _alignMenuItem(Icons.format_align_justify, 'Rata Kiri-Kanan', Attribute.justifyAlignment, c),
      ],
    );
  }

  Widget _alignMenuItem(
    IconData icon,
    String label,
    Attribute<String?> attr,
    QuillController c,
  ) {
    final active = c.getSelectionStyle().attributes[Attribute.align.key]?.value == attr.value;
    return MenuItemButton(
      onPressed: () {
        c.formatSelection(attr);
        afterPressed?.call();
      },
      leadingIcon: Icon(icon, size: 18, color: active ? const Color(0xFF2A9D8F) : null),
      child: Text(label),
    );
  }
}

/// Tombol dropdown daftar (bullet/angka/alphabet).
class _ToolbarListDropdown extends StatelessWidget {
  final QuillController controller;
  final VoidCallback? afterPressed;

  const _ToolbarListDropdown({required this.controller, this.afterPressed});

  @override
  Widget build(BuildContext context) {
    return _MenuToolbarButton(
      controller: controller,
      tooltip: 'Daftar',
      afterPressed: afterPressed,
      iconBuilder: (c) {
        final list = c.getSelectionStyle().attributes[Attribute.list.key]?.value;
        return Icon(
          switch (list) {
            'ordered' => Icons.format_list_numbered,
            'alpha' => Icons.format_list_numbered_rtl,
            _ => Icons.format_list_bulleted,
          },
          size: 15,
        );
      },
      menuBuilder: (c) {
        final list = c.getSelectionStyle().attributes[Attribute.list.key]?.value;
        return [
          _listMenuItem(Icons.format_list_bulleted, 'Bullet', 'bullet', list, c),
          _listMenuItem(Icons.format_list_numbered, 'Angka', 'ordered', list, c),
          _listMenuItem(Icons.format_list_numbered_rtl, 'Alphabet (a, b, c)', 'alpha', list, c),
        ];
      },
    );
  }

  Widget _listMenuItem(
    IconData icon,
    String label,
    String listValue,
    Object? current,
    QuillController c,
  ) {
    return MenuItemButton(
      onPressed: () {
        _applyList(c, listValue);
        afterPressed?.call();
      },
      leadingIcon: Icon(icon, size: 18, color: current == listValue ? const Color(0xFF2A9D8F) : null),
      child: Text(label),
    );
  }
}

/// Terapkan tipe list ke selection.
void _applyList(QuillController c, String listValue) {
  c.formatSelection(Attribute.fromKeyValue(Attribute.list.key, listValue));
}

/// Kontrol ukuran font: tampil angka (default 11), tanpa tombol hapus,
/// bisa input manual dengan batas min/max.
class _FontSizeControl extends StatefulWidget {
  final QuillController controller;
  final VoidCallback? afterPressed;

  const _FontSizeControl({required this.controller, this.afterPressed});

  @override
  State<_FontSizeControl> createState() => _FontSizeControlState();
}

class _FontSizeControlState extends State<_FontSizeControl> {
  final _menu = MenuController();
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_menu.isOpen) {
      _menu.close();
    } else {
      _menu.open();
    }
    widget.afterPressed?.call();
  }

  void _apply(double size) {
    final v = size.clamp(kMinFontSize, kMaxFontSize);
    widget.controller
        .formatSelection(Attribute.fromKeyValue(Attribute.size.key, v));
    _menu.close();
  }

  double? get _currentSize {
    final v = widget.controller
        .getSelectionStyle()
        .attributes[Attribute.size.key]
        ?.value;
    if (v is num) return v.toDouble();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final size = _currentSize;
        return MenuAnchor(
          controller: _menu,
          menuChildren: [
            for (final s in const [10, 11, 12, 14, 16, 18, 20, 24, 28, 32])
              MenuItemButton(
                onPressed: () => _apply(s.toDouble()),
                child: Text('$s', style: const TextStyle(fontSize: 13)),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: SizedBox(
                width: 130,
                child: TextField(
                  controller: _inputController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Ukuran ($kMinFontSize-$kMaxFontSize)',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (t) {
                    final v = double.tryParse(t.trim());
                    if (v != null) _apply(v);
                  },
                ),
              ),
            ),
          ],
          child: IconButton(
            tooltip: 'Ukuran font',
            onPressed: _toggle,
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(size ?? 11).round()}',
                  style: const TextStyle(fontSize: 13),
                ),
                const Icon(Icons.arrow_drop_down, size: 16),
              ],
            ),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
          ),
        );
      },
    );
  }
}

/// Shell tombol dropdown toolbar yang mengikuti perubahan controller.
class _MenuToolbarButton extends StatefulWidget {
  final QuillController controller;
  final Widget Function(QuillController) iconBuilder;
  final List<Widget> Function(QuillController) menuBuilder;
  final String tooltip;
  final VoidCallback? afterPressed;

  const _MenuToolbarButton({
    required this.controller,
    required this.iconBuilder,
    required this.menuBuilder,
    required this.tooltip,
    this.afterPressed,
  });

  @override
  State<_MenuToolbarButton> createState() => _MenuToolbarButtonState();
}

class _MenuToolbarButtonState extends State<_MenuToolbarButton> {
  final _menu = MenuController();

  void _toggle() {
    if (_menu.isOpen) {
      _menu.close();
    } else {
      _menu.open();
    }
    widget.afterPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return MenuAnchor(
          controller: _menu,
          menuChildren: widget.menuBuilder(widget.controller),
          child: IconButton(
            tooltip: widget.tooltip,
            onPressed: _toggle,
            icon: widget.iconBuilder(widget.controller),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
          ),
        );
      },
    );
  }
}

/// Editor rich tanpa toolbar
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
  // ponytail: ScrollController dipegang state
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
      // ponytail: paksa keyboard muncul
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
    // ponytail: placeholder default flutter_quill 20px terlalu besar;
    // samakan dengan ukuran teks form (14).
    final base =
        QuillStyles.getStyles(context, true) ?? DefaultStyles.getInstance(context);
    final ph = base.placeHolder;
    return QuillStyles(
      data: ph == null
          ? base
          : base.merge(DefaultStyles(
              placeHolder: ph.copyWith(style: ph.style.copyWith(fontSize: 14)),
            )),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
            // ponytail: pakai API eksperimental agar nomor list bisa desimal
            // (1,2,3) atau alphabet (a,b,c) sesuai atribut list.
            // ignore: experimental_member_use
            customLeadingBlockBuilder: (node, config) {
              final listValue = config.attribute.key == Attribute.list.key
                  ? config.attribute.value
                  : null;
              final isOrdered =
                  config.attribute == Attribute.ol || listValue == 'alpha';
              if (!isOrdered) return null;
              final isAlpha = listValue == 'alpha';
              final idx = config.index ?? _leadingLineIndex(node);
              final label = isAlpha ? _alphaLabel(idx) : idx.toString();
              return QuillNumberPoint(
                index: label,
                indentLevelCounts: config.indentLevelCounts,
                count: config.count,
                style: config.style ?? const TextStyle(),
                attrs: config.attrs,
                width: config.width ?? 24,
                padding: config.padding ?? 0,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Posisi 1-based baris dalam block-nya (untuk list alphabet, karena
/// flutter_quill hanya memberi index untuk list 'ordered').
int _leadingLineIndex(Node node) {
  final parent = node.parent;
  if (parent is Block) {
    var i = 0;
    for (final child in parent.children) {
      i++;
      if (child == node) return i;
    }
  }
  return 1;
}

/// Toolbar mengambang saat fokus
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

void _insertText(QuillController controller, String text) {
  final sel = controller.selection;
  final offset = sel.isValid ? sel.start : controller.document.length;
  controller.document.insert(offset, text);
  controller.updateSelection(
    TextSelection.collapsed(offset: offset + text.length),
    ChangeSource.local,
  );
}

/// Dialog insert rumus LaTeX
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

/// Dialog insert blok kode
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

/// Blok paragraf
class _RichBlock {
  final TextAlign? align;
  final List<InlineSpan> spans;
  final String plain;

  const _RichBlock(this.align, this.spans, this.plain);
}

/// Blok kode + tombol salin
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

/// Widget rumus matematika
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

/// Regex math $$/$
final _mathRegex = RegExp(r'\$\$[^$]+\$\$|\$[^$\n]+?\$');

/// Split teks + math
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

/// Split spans Delta + math
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

/// Render Delta/plain/HTML
class RichTextView extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final String prefix;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool ignoreInlineFontSize;

  const RichTextView({
    super.key,
    required this.text,
    this.style,
    this.prefix = '',
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.ignoreInlineFontSize = false,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final parsed = _contentBlocks(trimmed);
    final blocks = ignoreInlineFontSize ? _stripFontSizeFromBlocks(parsed) : parsed;
    final widgets = _blocksToWidgets(blocks);

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
    if (widgets.isEmpty) return const SizedBox.shrink();
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

      // Lewati blok yang hanya berisi spasi/baris kosong (mis. sisa enter
      // atau spasi di editor) supaya tidak membuat whitespace semu.
      if (t.isEmpty && !b.spans.any((s) => s is WidgetSpan)) {
        i++;
        continue;
      }

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

      if (t.startsWith('```')) {
        widgets.add(Text.rich(
          TextSpan(style: style, children: b.spans),
        ));
        i++;
        continue;
      }

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

/// Hapus tag HTML dasar
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

/// Pecah teks jadi blok
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

/// Pilih jalur render
List<_RichBlock> _contentBlocks(String raw) {
  final delta = _deltaBlocks(raw);
  if (delta != null) return delta;
  if (raw.startsWith('<')) {
    return _deltaOpsToBlocks(_htmlToDeltaOps(raw));
  }
  return _plainBlocks(_stripHtml(raw));
}

/// Delta JSON → blok
List<_RichBlock>? _deltaBlocks(String raw) {
  if (!raw.startsWith('[')) return null;
  final List ops;
  try {
    ops = jsonDecode(raw) as List;
  } catch (_) {
    return null;
  }
  return _deltaOpsToBlocks(ops);
}

/// Op Delta → blok
List<_RichBlock> _deltaOpsToBlocks(List ops) {
  final blocks = <_RichBlock>[];
  var current = <TextSpan>[];
  var buffer = StringBuffer();
  var orderedIndex = 0;
  var listType = '';
  var blockAlign = '';
  var blockHeader = 0;

  void flush() {
    final spans = <TextSpan>[];
    if (listType.isNotEmpty) {
      spans.add(TextSpan(
        text: switch (listType) {
          'ordered' => '${++orderedIndex}. ',
          'alpha' => '${_alphaLabel(++orderedIndex)}. ',
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
    if (listType != 'ordered' && listType != 'alpha') orderedIndex = 0;
    listType = '';
    blockAlign = '';
    blockHeader = 0;
  }

  for (final op in ops) {
    // ponytail: non-Delta jangan crash
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

/// Konversi indeks 1-based ke label alphabet (1→a, 2→b, …, 27→aa, …).
String _alphaLabel(int n) {
  var s = '';
  while (n > 0) {
    n--;
    s = String.fromCharCode(97 + (n % 26)) + s;
    n ~/= 26;
  }
  return s;
}

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

/// Hapus semua font-size inline dari blok rich text (mis. dari wysiwyg).
List<_RichBlock> _stripFontSizeFromBlocks(List<_RichBlock> blocks) {
  return [
    for (final b in blocks)
      _RichBlock(
        b.align,
        _stripFontSizeSpans(b.spans),
        b.plain,
      ),
  ];
}

List<InlineSpan> _stripFontSizeSpans(List<InlineSpan> spans) {
  return [
    for (final s in spans)
      if (s is TextSpan)
        TextSpan(
          text: s.text,
          style: s.style?.copyWith(fontSize: null),
          children: s.children == null ? null : _stripFontSizeSpans(s.children!),
        )
      else
        s,
  ];
}
