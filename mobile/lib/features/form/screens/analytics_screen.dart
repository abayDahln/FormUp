import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/widgets/search_field.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form/widgets/analytics_respondent_card.dart';
import 'package:form_up/features/form/widgets/analytics_summary_row.dart';

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
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
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
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchImmediate(String value) {
    _debounce?.cancel();
    if (!mounted) return;
    setState(() => _query = value.trim());
    _load();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
      _load();
    });
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
        search: _query,
      );
      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _respondents = analytics.respondents;
        _hasMore =
            analytics.respondents.length < analytics.totalResponses &&
                analytics.respondents.isNotEmpty;
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
        search: _query,
      );
      if (!mounted) return;
      setState(() {
        _page = next;
        _respondents = [..._respondents, ...analytics.respondents];
        _hasMore =
            analytics.respondents.length < analytics.totalResponses &&
                analytics.respondents.isNotEmpty;
      });
    } catch (e) {
      // ponytail: load-more gagal, scroll lagi
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openRespondent(RespondentAnalyticsData respondent) {
    AppRouter.of(context).push(AppPage.respondentDetail, {
      'formId': widget.formId,
      'title': widget.title,
      'responseId': respondent.responseId,
      'respondentName': respondent.respondentName ?? '',
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
          "Analisis Form",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: _loading && _analytics == null
          ? const Center(child: CircularProgressIndicator())
          : AuthBackground(plain: true,
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
                    if (_analytics != null)
                      AnalyticsSummaryRow(analytics: _analytics!),
                    const SizedBox(height: 16),
                    AppSearchField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSearchImmediate,
                      hint: 'Cari responden...',
                      historyKey: 'search_history_analytics',
                    ),
                    const SizedBox(height: 16),
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
                          children: [
                            const Icon(Icons.people_outline,
                                color: Colors.grey, size: 36),
                            const SizedBox(height: 10),
                            Text(
                              _query.isEmpty
                                  ? 'Belum ada responden'
                                  : 'Tidak ada hasil untuk "${_searchController.text}"',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      for (var i = 0; i < _respondents.length; i++) ...[
                        AnalyticsRespondentCard(
                          index: i,
                          respondent: _respondents[i],
                          onTap: () => _openRespondent(_respondents[i]),
                        ),
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
}
