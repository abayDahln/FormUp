import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/app_toast.dart' hide showAuthToast;
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

enum _RespondentSort { newest, oldest, highScore, lowScore }

extension _RespSortExt on _RespondentSort {
  String get label => switch (this) {
        _RespondentSort.newest => 'Terbaru',
        _RespondentSort.oldest => 'Terlama',
        _RespondentSort.highScore => 'Nilai tertinggi',
        _RespondentSort.lowScore => 'Nilai terendah',
      };
  IconData get icon => switch (this) {
        _RespondentSort.newest => Icons.schedule_outlined,
        _RespondentSort.oldest => Icons.history_outlined,
        _RespondentSort.highScore => Icons.arrow_upward_outlined,
        _RespondentSort.lowScore => Icons.arrow_downward_outlined,
      };
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
  bool _exporting = false;
  _RespondentSort _sort = _RespondentSort.newest;

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
    if (widget.formId == 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }
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
        _respondents = List<RespondentAnalyticsData>.from(analytics.respondents);
        _hasMore =
            analytics.respondents.isNotEmpty && analytics.respondents.length < analytics.totalResponses;
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
      setState(() {
        _analytics ??= const FormAnalytics();
        _respondents = _respondents.isEmpty ? const [] : _respondents;
        _hasMore = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading || widget.formId == 0) return;
    if (!_scrollController.hasClients) return;
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
        final seen = _respondents.map((r) => r.responseId).toSet();
        final novos = analytics.respondents.where((r) => !seen.contains(r.responseId)).toList();
        _respondents = [..._respondents, ...novos];
        _hasMore =
            analytics.respondents.isNotEmpty && analytics.respondents.length < analytics.totalResponses;
      });
    } catch (e) {
      if (mounted) showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<RespondentAnalyticsData> get _sortedRespondents {
    final list = List<RespondentAnalyticsData>.from(_respondents);
    switch (_sort) {
      case _RespondentSort.newest:
        list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
        break;
      case _RespondentSort.oldest:
        list.sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
        break;
      case _RespondentSort.highScore:
        list.sort((a, b) => (b.score ?? -1).compareTo(a.score ?? -1));
        break;
      case _RespondentSort.lowScore:
        list.sort((a, b) => (a.score ?? 999).compareTo(b.score ?? 999));
        break;
    }
    return list;
  }

  void _openRespondent(RespondentAnalyticsData respondent) {
    AppRouter.of(context).push(AppPage.respondentDetail, {
      'formId': widget.formId,
      'title': widget.title,
      'responseId': respondent.responseId,
      'respondentName': respondent.respondentName ?? '',
    });
  }

  Future<void> _openSortMenu() async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final offset = box != null && overlay != null ? box.localToGlobal(Offset.zero, ancestor: overlay) : Offset.zero;
    final result = await showMenu<_RespondentSort>(
      context: context,
      position: RelativeRect.fromLTRB(offset.dx + 200, offset.dy + 280, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        for (final s in _RespondentSort.values)
          PopupMenuItem<_RespondentSort>(
            value: s,
            child: Row(
              children: [
                Icon(s.icon, size: 18, color: _sort == s ? kAuthPrimary : Colors.black54),
                const SizedBox(width: 10),
                Text(s.label, style: TextStyle(fontSize: 14, color: _sort == s ? kAuthPrimary : Colors.black87, fontWeight: _sort == s ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          ),
      ],
    );
    if (result != null && mounted) setState(() => _sort = result);
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await FormService.exportResponses(widget.formId);
      if (!mounted) return;
      final xfile = XFile.fromData(
        bytes,
        name: 'responses-form-${widget.formId}.csv',
        mimeType: 'text/csv',
      );
      await SharePlus.instance.share(ShareParams(files: [xfile], text: 'Export responden ${widget.title}'));
      if (!mounted) return;
      showAppToast(context, 'CSV berhasil diekspor', title: 'Berhasil');
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
          "Responden",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _exporting
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: AppLoadingIndicator.inline()),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_outlined, color: Colors.black87),
                    tooltip: 'Export CSV',
                    onPressed: _export,
                  ),
          ),
        ],
      ),
      body: _loading && _analytics == null
          ? const AppLoadingOverlay()
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
                      filterActive: _sort != _RespondentSort.newest,
                      onOpenFilter: _openSortMenu,
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
                    if (_sortedRespondents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, color: Colors.black38, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty
                                  ? 'Belum ada responden'
                                  : 'Tidak ada hasil untuk "${_searchController.text}"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, color: Colors.black45),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      for (var i = 0; i < _sortedRespondents.length; i++) ...[
                        AnalyticsRespondentCard(
                          index: i,
                          respondent: _sortedRespondents[i],
                          onTap: () => _openRespondent(_sortedRespondents[i]),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_hasMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: AppLoadingIndicator.inline()),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
