import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'rich_editor.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';
import '../app_router.dart';

/// Analisis respons form
class AnalyticsScreen extends StatefulWidget {
  final int formId;
  final String title;

  const AnalyticsScreen({
    super.key,
    required this.formId,
    required this.title,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const _pageSize = 20;
  final _scrollController = ScrollController();
  FormAnalytics? _analytics;
  List<RespondentAnalyticsData> _respondents = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _page = 1;
      _hasMore = true;
    });
    try {
      final analytics = await FormService.getAnalytics(
        widget.formId,
        page: 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _respondents = analytics.respondents;
        _hasMore = analytics.respondents.length < analytics.totalResponses;
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final analytics = await FormService.getAnalytics(
        widget.formId,
        page: next,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = next;
        _respondents = [..._respondents, ...analytics.respondents];
        _hasMore = analytics.respondents.length < analytics.totalResponses;
      });
    } catch (e) {
      // ponytail: load-more gagal, scroll lagi
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title: const Text(
          "Analisis Form",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AuthBackground(
              child: SafeArea(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: softShadow(),
                      ),
                      child: RichTextView(
                        text: widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryRow(_analytics!),
                    const SizedBox(height: 20),
                    const Text(
                      "Responden",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_respondents.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.people_outline, color: Colors.grey, size: 36),
                            SizedBox(height: 10),
                            Text(
                              'Belum ada responden',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      for (var i = 0; i < _respondents.length; i++) ...[
                        _buildRespondentCard(i, _respondents[i]),
                        const SizedBox(height: 12),
                      ],
                      if (_hasMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryRow(FormAnalytics a) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Respons',
            value: '${a.totalResponses}',
            icon: Icons.people_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Soal',
            value: '${a.totalQuestions}',
            icon: Icons.list_alt_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Rata-rata Skor',
            value: a.averageScore == null
                ? '—'
                : '${a.averageScore!.toStringAsFixed(1)}%',
            icon: Icons.insights_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildRespondentCard(int index, RespondentAnalyticsData r) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: ExpansionTile(
        shape: const Border(),
        leading: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: kPrimarySoft,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: kAuthPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ),
        title: Text(
          (r.respondentName ?? '').trim().isEmpty
              ? 'Responden ${index + 1}'
              : r.respondentName!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          "${r.answeredCount}/${r.totalQuestions} dijawab · ${_formatTime(r.submittedAt)}",
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        trailing: _scoreChip(r.score),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (var i = 0; i < r.answers.length; i++)
            _buildAnswerRow(i, r.answers[i]),
        ],
      ),
    );
  }

  Widget _buildAnswerRow(int index, AnswerAnalyticsData a) {
    final answered = a.answerText != null && a.answerText!.isNotEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichTextView(
                  text: a.question,
                  prefix: '${index + 1}. ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (a.isCorrect != null)
                Icon(
                  a.isCorrect! ? Icons.check_circle : Icons.cancel,
                  color: a.isCorrect!
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC0392B),
                  size: 18,
                ),
            ],
          ),
          const SizedBox(height: 4),
          RichTextView(
            text: answered ? a.answerText! : 'Tidak dijawab',
            style: TextStyle(
              fontSize: 12,
              color: answered ? Colors.black87 : Colors.black45,
              fontStyle: answered ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          if (a.correctAnswer != null &&
              a.correctAnswer!.isNotEmpty &&
              a.correctAnswer != a.answerText) ...[
            const SizedBox(height: 4),
            RichTextView(
              text: 'Jawaban benar: ${a.correctAnswer}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scoreChip(double? score) {
    if (score == null) {
      return const Text(
        '—',
        style: TextStyle(fontSize: 13, color: Colors.black45),
      );
    }
    final color = score >= 75
        ? const Color(0xFF2E7D32)
        : score >= 50
            ? const Color(0xFFB26A00)
            : const Color(0xFFC0392B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${score.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
          color: color,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return "${local.day}/${local.month}/${local.year} $hh:$mm";
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: softShadow(),
      ),
      child: Column(
        children: [
          Icon(icon, color: kAuthPrimary, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
