import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/search_field.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/home/widgets/response_analytics_card.dart';
import 'package:form_up/features/home/widgets/response_history_group_card.dart';


enum _HistorySort { newest, oldest, mostAttempts }

extension _HistorySortLabel on _HistorySort {
  String get label => switch (this) {
        _HistorySort.newest => 'Terbaru',
        _HistorySort.oldest => 'Terlama',
        _HistorySort.mostAttempts => 'Kerjakan terbanyak',
      };
  IconData get icon => switch (this) {
        _HistorySort.newest => Icons.schedule,
        _HistorySort.oldest => Icons.history,
        _HistorySort.mostAttempts => Icons.repeat,
      };
}

enum _AnalyticsSort { newest, oldest, mostResponses }

extension _AnalyticsSortLabel on _AnalyticsSort {
  String get label => switch (this) {
        _AnalyticsSort.newest => 'Terbaru',
        _AnalyticsSort.oldest => 'Terlama',
        _AnalyticsSort.mostResponses => 'Respon terbanyak',
      };
  IconData get icon => switch (this) {
        _AnalyticsSort.newest => Icons.schedule,
        _AnalyticsSort.oldest => Icons.history,
        _AnalyticsSort.mostResponses => Icons.bar_chart,
      };
}

/// Tab Respons: riwayat & analisis — search & filter terpisah per tab
class ResponseScreen extends StatefulWidget {
  const ResponseScreen({super.key});

  @override
  State<ResponseScreen> createState() => _ResponseScreenState();
}

class _ResponseScreenState extends State<ResponseScreen> {
  List<MyResponseItem> _history = [];
  List<FormData> _myForms = [];
  bool _loading = true;

  // Search terpisah per tab
  final TextEditingController _historySearchController = TextEditingController();
  final TextEditingController _analyticsSearchController = TextEditingController();
  Timer? _historyDebounce;
  Timer? _analyticsDebounce;
  String _historyQuery = '';
  String _analyticsQuery = '';

  // Filter terpisah per tab
  _HistorySort _historySort = _HistorySort.newest;
  _AnalyticsSort _analyticsSort = _AnalyticsSort.newest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _historyDebounce?.cancel();
    _analyticsDebounce?.cancel();
    _historySearchController.dispose();
    _analyticsSearchController.dispose();
    super.dispose();
  }

  void _onHistorySearchImmediate(String value) {
    _historyDebounce?.cancel();
    if (!mounted) return;
    setState(() => _historyQuery = value.trim().toLowerCase());
  }

  void _onHistorySearchChanged(String value) {
    _historyDebounce?.cancel();
    _historyDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _historyQuery = value.trim().toLowerCase());
    });
  }

  void _onAnalyticsSearchImmediate(String value) {
    _analyticsDebounce?.cancel();
    if (!mounted) return;
    setState(() => _analyticsQuery = value.trim().toLowerCase());
  }

  void _onAnalyticsSearchChanged(String value) {
    _analyticsDebounce?.cancel();
    _analyticsDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _analyticsQuery = value.trim().toLowerCase());
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        FormService.getMyResponses(),
        FormService.getMyForms(),
      ]);
      if (!mounted) return;
      setState(() {
        _history = results[0] as List<MyResponseItem>;
        _myForms = results[1] as List<FormData>;
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAnalytics(FormData form) {
    AppRouter.of(context).push(AppPage.formAnalytics, {
      'formId': form.id,
      'title': form.title,
    });
  }

  // ── Filter sheet riwayat ──────────────────────────────
  Future<void> _openHistoryFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Filter Riwayat',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black87,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Urutkan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black54,
                ),
              ),
            ),
            RadioGroup<_HistorySort>(
              groupValue: _historySort,
              onChanged: (v) {
                if (v == null) return;
                Navigator.pop(sheetContext);
                setState(() => _historySort = v);
              },
              child: Column(
                children: [
                  for (final s in _HistorySort.values)
                    RadioListTile<_HistorySort>(
                      value: s,
                      dense: true,
                      secondary: Icon(s.icon, color: kAuthPrimary, size: 20),
                      title: Text(
                        s.label,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                ],
              ),
            ),
            if (_historySort != _HistorySort.newest)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    setState(() => _historySort = _HistorySort.newest);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kAuthPrimary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reset', style: TextStyle(color: kAuthPrimary, fontSize: 13)),
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Filter sheet analisis ─────────────────────────────
  Future<void> _openAnalyticsFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Filter Analisis',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black87,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Urutkan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black54,
                ),
              ),
            ),
            RadioGroup<_AnalyticsSort>(
              groupValue: _analyticsSort,
              onChanged: (v) {
                if (v == null) return;
                Navigator.pop(sheetContext);
                setState(() => _analyticsSort = v);
              },
              child: Column(
                children: [
                  for (final s in _AnalyticsSort.values)
                    RadioListTile<_AnalyticsSort>(
                      value: s,
                      dense: true,
                      secondary: Icon(s.icon, color: kAuthPrimary, size: 20),
                      title: Text(
                        s.label,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                ],
              ),
            ),
            if (_analyticsSort != _AnalyticsSort.newest)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    setState(() => _analyticsSort = _AnalyticsSort.newest);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kAuthPrimary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reset', style: TextStyle(color: kAuthPrimary, fontSize: 13)),
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 15, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Respons',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Riwayat & analisis respons',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ColoredBox(
              color: kAppBg,
              child: TabBar(
                labelColor: kPrimary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: kPrimary,
                indicatorWeight: 2.5,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'Riwayat'),
                  Tab(text: 'Analisis'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading && _history.isEmpty && _myForms.isEmpty
                  ? const Center(child: AppLoadingIndicator.circular())
                  : TabBarView(
                      children: [
                        _buildHistoryTab(),
                        _buildAnalyticsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── History: filter + sort + group ────────────────────
  List<MyResponseItem> get _filteredHistory {
    if (_historyQuery.isEmpty) return _history;
    return _history
        .where((e) => e.formTitle.toLowerCase().contains(_historyQuery))
        .toList();
  }

  List<ResponseHistoryGroup> get _groupedHistory {
    final items = _filteredHistory;
    final groups = <int, ResponseHistoryGroup>{};
    for (final item in items) {
      final group = groups.putIfAbsent(
        item.formId,
        () => ResponseHistoryGroup(item.formId, item.formTitle, item.formLink),
      );
      group.attempts.add(item);
    }
    final list = groups.values.toList();
    // sort sesuai filter
    switch (_historySort) {
      case _HistorySort.newest:
        list.sort((a, b) {
          final da = a.latest.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.latest.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
        break;
      case _HistorySort.oldest:
        list.sort((a, b) {
          final da = a.latest.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.latest.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return da.compareTo(db);
        });
        break;
      case _HistorySort.mostAttempts:
        list.sort((a, b) {
          final cmp = b.attempts.length.compareTo(a.attempts.length);
          if (cmp != 0) return cmp;
          final da = a.latest.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.latest.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
        break;
    }
    return list;
  }

  List<FormData> get _filteredForms {
    try {
      var list = List<FormData>.from(_myForms);
      final q = _analyticsQuery.trim().toLowerCase();
      if (q.isNotEmpty) {
        list = list
            .where((f) =>
                (f.title).toLowerCase().contains(q) ||
                (f.description ?? '').toLowerCase().contains(q))
            .toList();
      }
      switch (_analyticsSort) {
        case _AnalyticsSort.newest:
          list.sort((a, b) => (b.createdAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
          break;
        case _AnalyticsSort.oldest:
          list.sort((a, b) => (a.createdAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.createdAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
          break;
        case _AnalyticsSort.mostResponses:
          list.sort((a, b) => b.responseCount.compareTo(a.responseCount));
          break;
      }
      return list;
    } catch (_) {
      return List<FormData>.from(_myForms);
    }
  }

  Widget _buildHistoryTab() {
    final groups = _groupedHistory;
    final filterActive = _historySort != _HistorySort.newest;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppSearchField(
            controller: _historySearchController,
            onChanged: _onHistorySearchChanged,
            onSubmitted: _onHistorySearchImmediate,
            hint: 'Cari riwayat...',
            historyKey: 'search_history_response_history',
            filterActive: filterActive,
            onOpenFilter: _openHistoryFilterSheet,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildHistoryList(groups)),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    final forms = _filteredForms;
    final filterActive = _analyticsSort != _AnalyticsSort.newest;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppSearchField(
            controller: _analyticsSearchController,
            onChanged: _onAnalyticsSearchChanged,
            onSubmitted: _onAnalyticsSearchImmediate,
            hint: 'Cari form untuk analisis...',
            historyKey: 'search_history_response_analytics',
            filterActive: filterActive,
            onOpenFilter: _openAnalyticsFilterSheet,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildAnalyticsList(forms)),
      ],
    );
  }

  Widget _buildHistoryList(List<ResponseHistoryGroup> groups) {
    if (groups.isEmpty) {
      return AppRefreshIndicator(
        onRefresh: _load,
        indicatorColor: kAuthPrimary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, color: Colors.black38, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        _historyQuery.isEmpty ? 'Belum ada riwayat pengerjaan' : 'Tidak ada hasil untuk "${_historySearchController.text}"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return AppRefreshIndicator(
      onRefresh: _load,
      indicatorColor: kAuthPrimary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(kRadius),
              boxShadow: softShadow(),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < groups.length; i++)
                  ResponseHistoryTile(
                    group: groups[i],
                    showDivider: i != groups.length - 1,
                    onTap: () => AppRouter.of(context).push(
                      AppPage.historyFormDetail,
                      {
                        'formLink': groups[i].formLink,
                        'formTitle': groups[i].formTitle,
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsList(List<FormData> forms) {
    if (forms.isEmpty) {
      return AppRefreshIndicator(
        onRefresh: _load,
        indicatorColor: kAuthPrimary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bar_chart, color: Colors.black38, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        _analyticsQuery.isEmpty ? 'Belum ada form untuk dianalisis' : 'Tidak ada hasil untuk "${_analyticsSearchController.text}"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return AppRefreshIndicator(
      onRefresh: _load,
      indicatorColor: kAuthPrimary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(kRadius),
              boxShadow: softShadow(),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < forms.length; i++)
                  ResponseAnalyticsTile(
                    form: forms[i],
                    showDivider: i != forms.length - 1,
                    onTap: () => _openAnalytics(forms[i]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
