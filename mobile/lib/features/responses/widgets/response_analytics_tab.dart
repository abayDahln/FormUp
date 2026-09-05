import 'package:flutter/material.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/network_status.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Tab "Analisis" di screen responden — setara halaman Analisis & Diagram
/// di web:
/// - Ringkasan: total respon, pengguna unik, jumlah soal, rata-rata nilai.
/// - Distribusi nilai A–E (persen + bar).
/// - Tingkat kelulusan (skor >= 70) dengan persen lulus/tidak lulus.
/// - Akurasi per soal (persen benar, diurutkan dari yang tersulit).
/// - Peringkat responden dengan bar persen nilai.
class ResponseAnalyticsTab extends StatefulWidget {
  final int formId;
  final String title;

  const ResponseAnalyticsTab({
    super.key,
    required this.formId,
    this.title = '',
  });

  @override
  State<ResponseAnalyticsTab> createState() => _ResponseAnalyticsTabState();
}

class _ResponseAnalyticsTabState extends State<ResponseAnalyticsTab>
    with AutomaticKeepAliveClientMixin {
  FormAnalytics? _analytics;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    NetworkStatus.onlineTick.addListener(_onOnline);
  }

  @override
  void dispose() {
    NetworkStatus.onlineTick.removeListener(_onOnline);
    super.dispose();
  }

  void _onOnline() {
    if (mounted && NetworkStatus.isOnline) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Tanpa page/pageSize = semua responden + jawaban (analisis akurat).
      final data = await FormService.getAnalytics(widget.formId);
      if (!mounted) return;
      setState(() {
        _analytics = data;
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
    super.build(context);
    final data = _analytics;
    if (_loading && data == null) {
      return const AppLoadingOverlay(contained: true);
    }
    if (data == null) {
      return Center(
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Muat ulang'),
        ),
      );
    }
    if (data.respondents.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(28),
            decoration: _cardDecoration(),
            child: const Column(
              children: [
                Icon(Icons.analytics_outlined, size: 34, color: Colors.black26),
                SizedBox(height: 10),
                Text(
                  'Belum ada data analisis.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Analisis muncul setelah ada respon yang masuk.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Colors.black45),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final grades = _gradeDistribution(data);
    final pass = _passRate(data);
    final accuracy = _questionAccuracy(data);

    return RefreshIndicator(
      onRefresh: _load,
      color: kAuthPrimary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _summaryStrip(data),
          const SizedBox(height: 12),
          _gradeCard(grades),
          const SizedBox(height: 12),
          _passCard(pass),
          const SizedBox(height: 12),
          _accuracyCard(accuracy),
          const SizedBox(height: 12),
          _rankingCard(data),
        ],
      ),
    );
  }

  // ---- Perhitungan (mengikuti perhitungan versi web) ----

  ({Map<String, int> counts, int total}) _gradeDistribution(FormAnalytics d) {
    final counts = {'A': 0, 'B': 0, 'C': 0, 'D': 0, 'E': 0};
    var total = 0;
    for (final r in d.respondents) {
      final s = r.score;
      if (s == null) continue;
      total++;
      if (s >= 90) {
        counts['A'] = counts['A']! + 1;
      } else if (s >= 75) {
        counts['B'] = counts['B']! + 1;
      } else if (s >= 60) {
        counts['C'] = counts['C']! + 1;
      } else if (s >= 40) {
        counts['D'] = counts['D']! + 1;
      } else {
        counts['E'] = counts['E']! + 1;
      }
    }
    return (counts: counts, total: total);
  }

  ({int passed, int failed, int passPercent, int failPercent}) _passRate(
      FormAnalytics d) {
    var passed = 0;
    var failed = 0;
    for (final r in d.respondents) {
      final s = r.score;
      if (s == null) continue;
      if (s >= 70) {
        passed++;
      } else {
        failed++;
      }
    }
    final total = passed + failed;
    return (
      passed: passed,
      failed: failed,
      passPercent: total > 0 ? (passed / total * 100).round() : 0,
      failPercent: total > 0 ? (failed / total * 100).round() : 0,
    );
  }

  /// Akurasi per soal: id → (pertanyaan, benar, total dinilai, persen),
  /// diurutkan dari persen terendah (tersulit) — sama seperti web.
  List<({int id, String question, int correct, int total, int percent})>
      _questionAccuracy(FormAnalytics d) {
    final map = <int, ({String question, int correct, int total})>{};
    for (final r in d.respondents) {
      for (final a in r.answers) {
        if (a.isCorrect == null) continue;
        final cur = map[a.questionId] ??
            (question: a.question, correct: 0, total: 0);
        map[a.questionId] = (
          question: cur.question,
          correct: cur.correct + (a.isCorrect == true ? 1 : 0),
          total: cur.total + 1,
        );
      }
    }
    final list = map.entries
        .map((e) => (
              id: e.key,
              question: e.value.question,
              correct: e.value.correct,
              total: e.value.total,
              percent: e.value.total > 0
                  ? (e.value.correct / e.value.total * 100).round()
                  : 0,
            ))
        .toList()
      ..sort((x, y) => x.percent.compareTo(y.percent));
    return list;
  }

  // ---- UI helpers ----

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBDC9C8)),
        boxShadow: softShadow(),
      );

  int _pct(int part, int total) => total > 0 ? (part / total * 100).round() : 0;

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: child,
      );

  Widget _cardTitle(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 15, color: kAuthPrimary),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      );

  /// Bar persen horizontal: [teal fill][track] + label persen di kanan.
  Widget _percentBar(
    int percent, {
    Color color = kAuthPrimary,
    String? label,
  }) {
    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3ECEB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (percent / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: label != null ? null : 34,
          child: Text(
            label ?? '$percent%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  // ---- Kartu-kartu ----

  Widget _summaryStrip(FormAnalytics d) {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _summaryCell('Total Respon', '${d.totalResponses}'),
              _verticalDivider(),
              _summaryCell('Pengguna Unik', '${d.totalDistinctUsers}'),
            ],
          ),
          const Divider(height: 18, thickness: 0.7, color: Color(0xFFE3ECEB)),
          Row(
            children: [
              _summaryCell('Total Soal', '${d.totalQuestions}'),
              _verticalDivider(),
              _summaryCell(
                'Rata-rata Nilai',
                d.averageScore != null
                    ? d.averageScore!.toStringAsFixed(1)
                    : '-',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCell(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                fontFamily: kFontBold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      );

  Widget _verticalDivider() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: const Color(0xFFE3ECEB),
      );

  Widget _gradeCard(({Map<String, int> counts, int total}) grades) {
    const meta = {
      'A': (Colors.green, '≥ 90'),
      'B': (kAuthPrimary, '≥ 75'),
      'C': (Colors.orange, '≥ 60'),
      'D': (Colors.deepOrange, '≥ 40'),
      'E': (Colors.red, '< 40'),
    };
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Distribusi Nilai', Icons.stacked_bar_chart_rounded),
          for (final g in const ['A', 'B', 'C', 'D', 'E'])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      g,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: (meta[g]!.$1),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _percentBar(
                      _pct(grades.counts[g]!, grades.total),
                      color: meta[g]!.$1,
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${grades.counts[g]}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Skor ${grades.total} responden dinilai • A ≥ 90, B ≥ 75, C ≥ 60, D ≥ 40, E < 40',
            style: const TextStyle(fontSize: 10, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _passCard(({int passed, int failed, int passPercent, int failPercent})
      pass) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Tingkat Kelulusan (skor ≥ 70)', Icons.verified_outlined),
          Row(
            children: [
              Expanded(
                child: _bigPercent('${pass.passPercent}%', 'Lulus',
                    Colors.green.shade700, '${pass.passed} responden'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bigPercent('${pass.failPercent}%', 'Tidak Lulus',
                    Colors.red.shade600, '${pass.failed} responden'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _percentBar(
                  pass.passPercent,
                  color: Colors.green,
                  label: '',
                ),
              ),
              Expanded(
                child: _percentBar(
                  pass.failPercent,
                  color: Colors.red,
                  label: '',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bigPercent(String percent, String label, Color color, String sub) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              percent,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                fontFamily: kFontBold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ],
        ),
      );

  Widget _accuracyCard(
      List<({int id, String question, int correct, int total, int percent})>
          accuracy) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Akurasi Per Soal (tersulit dulu)', Icons.track_changes_rounded),
          if (accuracy.isEmpty)
            const Text(
              'Belum ada soal yang bisa dinilai otomatis.',
              style: TextStyle(fontSize: 11.5, color: Colors.black45),
            )
          else
            for (final q in accuracy)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _clean(q.question).isEmpty
                                ? 'Soal #${q.id}'
                                : _clean(q.question),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${q.correct}/${q.total}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: q.percent >= 70
                                ? Colors.green
                                : (q.percent >= 40
                                    ? Colors.orange
                                    : Colors.red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _percentBar(
                      q.percent,
                      color: q.percent >= 70
                          ? Colors.green
                          : (q.percent >= 40 ? Colors.orange : Colors.red),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _rankingCard(FormAnalytics d) {
    final ranked = [...d.respondents]
      ..sort((x, y) => (y.score ?? -1).compareTo(x.score ?? -1));
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Peringkat Responden', Icons.leaderboard_rounded),
          for (var i = 0; i < ranked.length; i++)
            () {
              final r = ranked[i];
              return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                AppRouter.of(context).push(AppPage.respondentDetail, {
                  'formId': widget.formId,
                  'title': widget.title,
                  'responseId': r.responseId,
                  'respondentName': r.respondentName ?? '',
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: i < 3 ? kAuthPrimary : Colors.black38,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (r.respondentName?.isNotEmpty ?? false)
                                ? r.respondentName!
                                : 'Anonim',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _percentBar(
                            r.score != null ? r.score!.clamp(0, 100).round() : 0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r.score != null
                          ? r.score!.toStringAsFixed(0)
                          : '-',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.black54,
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 16, color: Colors.black26),
                  ],
                ),
              ),
              );
            }(),
        ],
      ),
    );
  }

  String _clean(String? s) => (s ?? '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
