import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form/widgets/history_answer_card.dart';

/// Detail jawaban lengkap satu responden untuk sebuah form.
/// Default menampilkan respon TERBARU; responden yang mengerjakan lebih
/// dari sekali bisa memilih attempt lain berdasarkan waktu pengerjaan.
class RespondentDetailScreen extends StatefulWidget {
  final int formId;
  final String title;
  final int responseId;
  final String respondentName;

  const RespondentDetailScreen({
    super.key,
    required this.formId,
    required this.responseId,
    this.title = '',
    this.respondentName = '',
  });

  @override
  State<RespondentDetailScreen> createState() => _RespondentDetailScreenState();
}

class _RespondentDetailScreenState extends State<RespondentDetailScreen> {
  bool _loading = true;
  PublicFormResult? _result;
  List<MyAttempt> _attempts = [];
  late int _selectedResponseId;

  @override
  void initState() {
    super.initState();
    _selectedResponseId = widget.responseId;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        FormService.getResponseResult(widget.formId, _selectedResponseId),
        FormService.getRespondentAttempts(widget.formId, widget.responseId),
      ]);
      if (!mounted) return;
      setState(() {
        _result = results[0] as PublicFormResult;
        _attempts = results[1] as List<MyAttempt>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  Future<void> _selectAttempt(int responseId) async {
    if (responseId == _selectedResponseId) return;
    setState(() {
      _selectedResponseId = responseId;
      _loading = true;
    });
    try {
      final result =
          await FormService.getResponseResult(widget.formId, responseId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.respondentName.trim().isNotEmpty
        ? widget.respondentName.trim()
        : 'Responden';
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
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: _loading && _result == null
          ? const Center(child: AppLoadingIndicator.circular())
          : AuthBackground(plain: true,
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    if (_attempts.length > 1) ...[
                      _buildAttemptSelector(),
                      const SizedBox(height: 16),
                    ],
                    _buildSummaryCard(),
                    const SizedBox(height: 16),
                    Text(
                      _result?.showScore == true
                          ? "Pembahasan Jawaban"
                          : "Jawaban Responden",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_result == null || _result!.answers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          "Belum ada jawaban.",
                          style:
                              TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      )
                    else
                      for (var i = 0; i < _result!.answers.length; i++) ...[
                        HistoryAnswerCard(
                          index: i,
                          answer: _result!.answers[i],
                          showScore: _result!.showScore,
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
    );
  }

  /// Pemilih attempt: chip horizontal dibedakan berdasarkan waktu pengerjaan.
  /// Percobaan terbaru otomatis terpilih saat screen dibuka.
  Widget _buildAttemptSelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _attempts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final attempt = _attempts[i];
          final selected = attempt.responseId == _selectedResponseId;
          final dt = attempt.submittedAt?.toLocal();
          final label = dt == null
              ? "Percobaan ${i + 1}"
              : "Percobaan ${i + 1} · "
                  "${dt.day}/${dt.month}/${dt.year} "
                  "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _selectAttempt(attempt.responseId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? kAuthPrimary : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? kAuthPrimary : const Color(0xFFBDC9C8),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  fontFamily: selected ? kFontBold : null,
                  color: selected ? Colors.white : Colors.black54,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard() {
    final result = _result;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichTextView(
            text: widget.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _submittedText(),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCell("${result.answeredCount}/${result.totalQuestions}",
                    "Dijawab"),
                if (result.showScore)
                  _StatCell(result.score?.toStringAsFixed(1) ?? "—", "Skor"),
                if (result.showScore)
                  _StatCell("${result.correctCount}", "Benar",
                      color: const Color(0xFF2E7D32)),
                if (result.showScore)
                  _StatCell("${result.wrongCount}", "Salah",
                      color: const Color(0xFFC0392B)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _submittedText() {
    // Waktu attempt aktif diambil dari daftar attempt kalau tersedia.
    for (final a in _attempts) {
      if (a.responseId == _selectedResponseId && a.submittedAt != null) {
        final dt = a.submittedAt!.toLocal();
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        return "Dikerjakan ${dt.day}/${dt.month}/${dt.year} $hh:$mm";
      }
    }
    return "";
  }
}

/// Satu sel statistik pada kartu ringkasan
class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCell(this.value, this.label, {this.color = Colors.black87});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}
