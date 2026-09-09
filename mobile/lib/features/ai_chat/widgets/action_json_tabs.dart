import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Tab layout untuk blok ```json aksi AI di dalam jawaban:
/// - Tab "Preview": soal-soal dirender rapi dengan RichTextView — renderer
///   yang sama dengan screen edit/pratinjau/pengerjaan soal (rich text +
///   LaTeX via flutter_math_fork).
///   lengkap chip tipe/wajib/poin, opsi berhuruf A-E, dan tanda jawaban benar.
/// - Tab "JSON": raw JSON yang di-pretty-print dalam code block.
/// Widget ini hanya dipasang saat JSON SUDAH lengkap (streaming setengah
/// tetap tampil sebagai code block biasa).
class ActionJsonTabs extends StatefulWidget {
  final Map<String, dynamic> action;

  const ActionJsonTabs({super.key, required this.action});

  @override
  State<ActionJsonTabs> createState() => _ActionJsonTabsState();
}

class _ActionJsonTabsState extends State<ActionJsonTabs> {
  static const _typeNames = {
    1: 'Esai',
    2: 'Pilihan Ganda',
    3: 'Checkbox',
    4: 'Date Time',
    5: 'True / False',
  };

  int _tab = 0; // 0 = Preview, 1 = JSON

  /// Skema warna tema aktif agar seluruh kartu sadar-tema (terang/gelap).
  ColorScheme get _cs => Theme.of(context).colorScheme;

  String _clean(String? s) => (s ?? '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _typeLabel(dynamic typeId) =>
      _typeNames[typeId is int ? typeId : int.tryParse('$typeId')] ?? 'Soal';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tabBar(),
          Divider(height: 1, thickness: 0.7, color: _cs.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _tab == 0 ? _preview() : _jsonView(),
          ),
        ],
      ),
    );
  }

  // ---- Tab bar ----

  Widget _tabBar() {
    return Row(
      children: [
        _tabItem(0, Icons.visibility_outlined, 'Preview'),
        _tabItem(1, Icons.code_rounded, 'JSON'),
      ],
    );
  }

  Widget _tabItem(int index, IconData icon, String label) {
    final active = _tab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? _cs.primaryContainer : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 13,
                  color: active ? _cs.primary : _cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? _cs.primary : _cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Tab Preview ----

  Widget _preview() {
    final a = widget.action;
    switch (a['action']) {
      case 'create_form':
        final title = _clean(a['title'] as String?);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              _formTitleLine(title),
              const SizedBox(height: 8),
            ],
            ..._questionList(a),
          ],
        );
      case 'add_questions':
      case 'edit_questions':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _questionList(a),
        );
      case 'delete_questions':
        final n = (a['questionIds'] as List<dynamic>?)?.length ?? 0;
        return Text(
          '$n soal akan dihapus dari form. Rincian soalnya ada di kartu perubahan di bawah.',
          style: TextStyle(fontSize: 13, color: _cs.onSurfaceVariant),
        );
      case 'update_settings':
        final settings = a['settings'] as Map<dynamic, dynamic>? ?? {};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final k in settings.keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        '$k',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700, fontFamily: kFontBold,
                          color: _cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: RichTextView(
                        text: '${settings[k]}',
                        style: TextStyle(
                            fontSize: 13, color: _cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      default:
        return _jsonView();
    }
  }

  Widget _formTitleLine(String title) => Row(
        children: [
          Icon(Icons.description_outlined, size: 14, color: _cs.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700, fontFamily: kFontBold,
                color: _cs.onSurface,
              ),
            ),
          ),
        ],
      );

  List<Widget> _questionList(Map<String, dynamic> a) {
    final questions = a['questions'] as List<dynamic>? ?? [];
    return [
      for (var i = 0; i < questions.length; i++)
        _questionCard(questions[i] as Map, i),
    ];
  }

  Widget _questionCard(Map q, int index) {
    final orderRaw = q['questionOrder'] ?? q['order'];
    final order = orderRaw is int
        ? orderRaw
        : int.tryParse('${orderRaw ?? ''}');
    final isRequired = q['isRequired'] == true;
    final points = q['points'];
    final options = q['options'] as List<dynamic>? ?? [];
    final correct = q['correctAnswer'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _chip(
                'Soal ${order ?? index + 1}',
                color: _cs.primary,
                filled: true,
              ),
              _chip(_typeLabel(q['typeId'])),
              if (isRequired) _chip('Wajib', color: Colors.orange),
              if (points != null) _chip('$points poin'),
            ],
          ),
          const SizedBox(height: 6),
          // Render sama dengan screen edit/pratinjau/pengerjaan soal:
          // rich text + LaTeX ($...$, $$...$$) via flutter_math_fork.
          RichTextView(
            text: _clean(q['question'] as String?),
            style: TextStyle(fontSize: 14, color: _cs.onSurface),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < options.length; i++) _optionRow(options[i], i),
          ],
          if (correct != null && '$correct'.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.check_circle, size: 13, color: Colors.green),
                const SizedBox(width: 4),
                Expanded(
                  child: RichTextView(
                    text: _clean('$correct'),
                    style: TextStyle(
                        fontSize: 13, color: Colors.green.shade700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionRow(dynamic o, int index) {
    String text;
    bool isCorrect = false;
    if (o is String) {
      text = o;
    } else if (o is Map) {
      text = '${o['optionText'] ?? ''}';
      isCorrect = o['isCorrect'] == true;
    } else {
      text = '$o';
    }
    final letter = String.fromCharCode(65 + index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$letter.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700, fontFamily: kFontBold,
                color: isCorrect ? Colors.green : _cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: RichTextView(
              text: _clean(text),
              style: TextStyle(fontSize: 13, color: _cs.onSurface),
            ),
          ),
          if (isCorrect)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.check_circle, size: 14, color: Colors.green),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, {Color? color, bool filled = false}) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? c.withValues(alpha: 0.14) : cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled ? c.withValues(alpha: 0.4) : cs.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700, fontFamily: kFontBold,
          color: filled ? c : cs.onSurfaceVariant,
        ),
      ),
    );
  }

  // ---- Tab JSON ----

  Widget _jsonView() {
    final pretty = const JsonEncoder.withIndent('  ').convert(widget.action);
    return GptMarkdown(
      '```json\n$pretty\n```',
      style:  TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface),
    );
  }
}
