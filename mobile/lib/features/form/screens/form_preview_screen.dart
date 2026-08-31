import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/answer_fields.dart';
import 'package:form_up/core/utils/form_zoom.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/features/form/widgets/form_zoom_controls.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/router/app_router.dart';

/// Pratinjau responden
class FormPreviewScreen extends StatefulWidget {
  final int formId;

  const FormPreviewScreen({super.key, required this.formId});

  @override
  State<FormPreviewScreen> createState() => _FormPreviewScreenState();
}

class _FormPreviewScreenState extends State<FormPreviewScreen> {
  bool _loading = true;
  String _title = '';
  String _description = '';
  List<QuestionData> _questions = [];

  final Map<int, TextEditingController> _textAnswers = {};
  final Map<int, int?> _singleAnswers = {};
  final Map<int, Set<int>> _multiAnswers = {};
  final Map<int, String?> _tfAnswers = {};
  final Map<int, DateTime?> _datetimeAnswers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _textAnswers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final form = await FormService.getForm(widget.formId);
      final questions = await FormService.getQuestions(widget.formId);
      if (!mounted) return;
      _initAnswers(questions);
      setState(() {
        _title = form['title'] as String? ?? '';
        _description = form['description'] as String? ?? '';
        _questions = questions;
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _initAnswers(List<QuestionData> questions) {
    _textAnswers.clear();
    _singleAnswers.clear();
    _multiAnswers.clear();
    _tfAnswers.clear();
    _datetimeAnswers.clear();
    for (final q in questions) {
      switch (q.typeId) {
        case 1:
          _textAnswers[q.id] = TextEditingController();
          break;
        case 4:
          _datetimeAnswers[q.id] = null;
          break;
        case 5:
          _tfAnswers[q.id] = null;
          break;
        case 2:
          _singleAnswers[q.id] = null;
          break;
        case 3:
          _multiAnswers[q.id] = {};
          break;
      }
    }
  }

  Future<void> _pickDateTime(int questionId) async {
    final now = DateTime.now();
    final initial = _datetimeAnswers[questionId] ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      _datetimeAnswers[questionId] =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xCCBDC9C8)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title: const Text(
          "Pratinjau Form",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 8), child: Center(child: FormZoomControls())),
        ],
      ),
      body: _loading
          ? const AppLoadingOverlay()
          : ValueListenableBuilder<double>(
              valueListenable: formZoom,
              builder: (context, zoom, _) => AuthBackground(
                plain: true,
                child: SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          children: [
                            _buildHeader(zoom),
                            const SizedBox(height: 16),
                            for (var i = 0; i < _questions.length; i++) ...[
                              _buildQuestionCard(i, zoom),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader([double zoom = 1.0]) {
    double zs(double v) => (v * zoom).clamp(10, 48).toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichTextView(
            text: _title,
            zoom: zoom,
            style: TextStyle(
              fontSize: zs(18),
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          if (_description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            RichTextView(
              text: _description,
              zoom: zoom,
              style: TextStyle(fontSize: zs(12), color: Colors.black54),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            "${_questions.length} pertanyaan · ${_questions.where((q) => q.isRequired == true).length} wajib dijawab",
            style: TextStyle(fontSize: zs(12), color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index, [double zoom = 1.0]) {
    double zs(double v) => (v * zoom).clamp(10, 48).toDouble();
    final q = _questions[index];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: kPrimarySoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: kAuthPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichTextView(
                  text: q.question,
                  zoom: zoom,
                  style: TextStyle(
                    fontSize: zs(14),
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (q.isRequired == true)
                const Text(
                  "*",
                  style: TextStyle(color: Color(0xFFC0392B), fontSize: 16),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AnswerFields(
            zoom: zoom,
            typeId: q.typeId,
            options: [
              for (final o in q.options)
                if (o.id != null) AnswerOption(o.id!, o.optionText),
            ],
            essayController: _textAnswers[q.id],
            singleValue: _singleAnswers[q.id],
            multiValue: _multiAnswers[q.id] ?? {},
            tfValue: _tfAnswers[q.id],
            dateLabel: _datetimeAnswers[q.id] == null
                ? null
                : _formatDateTime(_datetimeAnswers[q.id]!),
            onSingleChanged: (v) => setState(() => _singleAnswers[q.id] = v),
            onMultiChanged: (v) => setState(() => _multiAnswers[q.id] = v),
            onTfChanged: (v) => setState(() => _tfAnswers[q.id] = v),
            onPickDateTime: () => _pickDateTime(q.id),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return "${local.day} ${months[local.month - 1]} ${local.year}, $hh:$mm";
  }
}

