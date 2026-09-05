import 'dart:async';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:form_up/core/widgets/ai_chat_icon.dart';
import 'package:form_up/core/widgets/loading_indicator.dart';import 'package:form_up/core/widgets/progress_indicator.dart' as progress;
import 'package:form_up/core/widgets/app_toast.dart' hide showAuthToast;
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/widgets/search_field.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/network_status.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form/widgets/analytics_respondent_card.dart';
import 'package:form_up/features/form/widgets/analytics_summary_row.dart';
import 'package:form_up/features/responses/widgets/response_analytics_tab.dart';

/// Analisis respons form — 2 tab: Analisis (diagram persen seperti web)
/// dan Respon (daftar responden).
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

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  static const _pageSize = 10;
  final _searchController = TextEditingController();
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
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

  int get _totalPages {
    final total = _analytics?.totalDistinctUsers ?? _analytics?.totalResponses ?? 0;
    if (total == 0) return 1;
    return (total / _pageSize).ceil();
  }

  bool get _showPagination {
    final distinct = _analytics?.totalDistinctUsers ?? 0;
    // Jika backend belum kirim distinct, fallback ke estimasi group lokal
    final fallbackDistinct = _groupedRespondents.length;
    final count = distinct > 0 ? distinct : fallbackDistinct;
    return count > 20;
  }

  @override
  void initState() {
    super.initState();
    NetworkStatus.onlineTick.addListener(_onOnline);
    _load();
  }

  void _onOnline() {
    if (mounted && NetworkStatus.isOnline) _load();
  }

  @override
  void dispose() {
    NetworkStatus.onlineTick.removeListener(_onOnline);
    _debounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _responScrollController.dispose();
    super.dispose();
  }

  void _onSearchImmediate(String value) {
    if (_exporting) return;
    _debounce?.cancel();
    if (!mounted) return;
    setState(() => _query = value.trim());
    _load();
  }

  void _onSearchChanged(String value) {
    if (_exporting) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
      _load();
    });
  }

  /// Controller list tab Respon — untuk kembali ke atas saat ganti halaman.
  final _responScrollController = ScrollController();

  void _scrollListToTop() {
    if (_responScrollController.hasClients) {
      _responScrollController.jumpTo(0);
    }
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
        _hasMore = _respondents.length < analytics.totalResponses;
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
        _hasMore = _respondents.length < analytics.totalResponses;
      });
    } catch (e) {
      if (mounted) showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _goToPage(int target) async {
    if (target < 1 || target > _totalPages || _loading || _loadingMore) return;
    setState(() {
      _loading = true;
      _page = target;
    });
    try {
      final analytics = await FormService.getAnalytics(
        widget.formId,
        page: target,
        pageSize: _pageSize,
        search: _query,
      );
      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _respondents = List<RespondentAnalyticsData>.from(analytics.respondents);
        _hasMore = _respondents.length < analytics.totalResponses;
      });
      _scrollListToTop();
    } catch (e) {
      if (mounted) showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
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

  /// Gabungkan responden berdasarkan user yang sama (nama lower-case).
  /// Kunci: nama trimmed lower; fallback "anonim" untuk null.
  /// Setiap grup menyimpan percobaan terbaru sebagai wakil untuk kartu.
  List<_GroupedRespondent> get _groupedRespondents {
    final sorted = _sortedRespondents;
    final Map<String, List<RespondentAnalyticsData>> groups = {};
    for (final r in sorted) {
      final key = (r.respondentName ?? '').trim().toLowerCase();
      final k = key.isEmpty ? '__anonim__' : key;
      groups.putIfAbsent(k, () => []).add(r);
    }
    final grouped = <_GroupedRespondent>[];
    for (final entry in groups.entries) {
      final list = entry.value;
      // Wakil = percobaan terbaru (submittedAt paling baru)
      list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      final latest = list.first;
      // Skor terbaik untuk sort highScore jika grup diurutkan ulang? Keep latest.
      grouped.add(_GroupedRespondent(
        displayName: latest.respondentName?.trim().isEmpty == true ? 'Anonim' : latest.respondentName!.trim(),
        latest: latest,
        attempts: list,
      ));
    }
    // Urutkan grup sesuai _sort tapi pakai wakil terbaru
    switch (_sort) {
      case _RespondentSort.newest:
        grouped.sort((a, b) => b.latest.submittedAt.compareTo(a.latest.submittedAt));
        break;
      case _RespondentSort.oldest:
        grouped.sort((a, b) => a.latest.submittedAt.compareTo(b.latest.submittedAt));
        break;
      case _RespondentSort.highScore:
        grouped.sort((a, b) => (b.latest.score ?? -1).compareTo(a.latest.score ?? -1));
        break;
      case _RespondentSort.lowScore:
        grouped.sort((a, b) => (a.latest.score ?? 999).compareTo(b.latest.score ?? 999));
        break;
    }
    return grouped;
  }

  void _openRespondent(RespondentAnalyticsData respondent) {
    if (_exporting) return;
    AppRouter.of(context).push(AppPage.respondentDetail, {
      'formId': widget.formId,
      'title': widget.title,
      'responseId': respondent.responseId,
      'respondentName': respondent.respondentName ?? '',
    });
  }

  Future<void> _openSortMenu() async {
    if (_exporting) return;
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

  Future<String?> _pickExportFormat() => showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Text('Pilih format ekspor', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold)),
            const SizedBox(height: 8),
            for (final f in ['csv', 'xlsx', 'pdf'])
              ListTile(
                leading: Icon(f == 'pdf' ? Icons.picture_as_pdf_outlined : f == 'xlsx' ? Icons.table_chart_outlined : Icons.description_outlined, color: kAuthPrimary),
                title: Text(f.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold)),
                onTap: () => Navigator.pop(ctx, f),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      );

  String _sanitizeFileName(String name) {
    var s = name.trim();
    if (s.isEmpty) s = 'form-${widget.formId}';
    s = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceAll(RegExp(r'[^\w\s\-().]'), '_');
    if (s.length > 80) s = s.substring(0, 80).trim();
    if (s.isEmpty) s = 'form-${widget.formId}';
    return s;
  }

  Future<void> _shareExport(Uint8List bytes, String fileName, String mime, String format) async {
    final xfile = XFile.fromData(bytes, name: fileName, mimeType: mime);
    await SharePlus.instance.share(ShareParams(files: [xfile], text: 'Export responden ${widget.title} ($format)'));
  }

  Future<void> _showExportDoneDialog(Uint8List bytes, String fileName, String mime, String format) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.check_circle, color: kPrimary), SizedBox(width: 8), Text('Ekspor Selesai', style: TextStyle(fontFamily: kFontBold))]),
        content: Text('File "$fileName" berhasil dibuat (${(bytes.length / 1024).toStringAsFixed(1)} KB).', style: const TextStyle(fontSize: 13, color: Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          FilledButton.icon(onPressed: () async { Navigator.pop(ctx); await _shareExport(bytes, fileName, mime, format); }, icon: const Icon(Icons.share_outlined, size: 18), label: const Text('Bagikan')),
        ],
      ),
    );
  }

  Future<void> _export() async {
    if (_exporting) return;
    final format = await _pickExportFormat();
    if (format == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final bytes = await FormService.exportResponses(widget.formId, format: format);
      if (!mounted) return;
      final mime = format == 'xlsx' ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' : format == 'pdf' ? 'application/pdf' : 'text/csv';
      final fileName = '${_sanitizeFileName(widget.title)}.$format';
      await _showExportDoneDialog(bytes, fileName, mime, format);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Buka AI chat dengan form ini di-mention + prompt analisis siap kirim
  /// (seperti Analisis AI di web — user yang menekan kirim sendiri).
  void _openAiAnalysis() {
    if (_exporting || widget.formId == 0) return;
    AppRouter.of(context).push(AppPage.aiChat, {
      'formId': widget.formId,
      'initialPrompt': _buildAiPrompt(),
    });
  }

  /// Prompt analisis hasil form — ringkasan data + instruksi analisis
  /// (mengikuti prompt Analisis AI di web).
  String _buildAiPrompt() {
    final a = _analytics;
    final buf = StringBuffer();
    buf.writeln('Data ringkasan hasil "${widget.title}":');
    buf.writeln('- Total respon: ${a?.totalResponses ?? 0}');
    buf.writeln('- Pengguna unik: ${a?.totalDistinctUsers ?? 0}');
    buf.writeln('- Total soal: ${a?.totalQuestions ?? 0}');
    if (a?.averageScore != null) {
      buf.writeln(
          '- Rata-rata nilai: ${a!.averageScore!.toStringAsFixed(1)}');
    }
    return '''Tolong berikan analisis mendalam dan rekomendasi perbaikan dari hasil form ini dalam bahasa Indonesia yang jelas dan mudah dipahami guru.

${buf.toString()}
Berikan analisis yang mencakup:
1. Interpretasi distribusi nilai dan apa artinya bagi kualitas pembelajaran
2. Soal-soal bermasalah (terlalu sulit/mudah) dan saran perbaikannya
3. Rekomendasi konkret untuk meningkatkan hasil belajar
4. Kesimpulan umum tentang kualitas soal dan pemahaman siswa''';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_exporting,
      onPopInvokedWithResult: (didPop, _) { if (!didPop && _exporting) showAppToast(context, 'Tunggu ekspor selesai', type: ToastType.warning); },
      child: Scaffold(
        backgroundColor: kAppBg,
        floatingActionButton: FloatingActionButton.small(
          heroTag: 'aiAnalysisForForm',
          onPressed: _exporting ? null : _openAiAnalysis,
          tooltip: 'Analisis AI dengan form ini',
          child: AiChatIcon(
            size: 20,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            filled: true,
          ),
        ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xCCBDC9C8)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _exporting ? null : () => AppRouter.of(context).pop(),
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
                    child: SizedBox(width: 20, height: 20, child: LoadingIndicator.inline()),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_outlined, color: Colors.black87),
                    tooltip: 'Export CSV/XLSX/PDF',
                    onPressed: _export,
                  ),
          ),
        ],
      ),
      body: NestedScrollView(
        // Tab bar ikut tergulung bersama konten (bukan fixed di appbar).
        headerSliverBuilder: (context, _) =>
            [SliverToBoxAdapter(child: _MintTabBar(controller: _tabController))],
        body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab Analisis: diagram persen & analisis mendetail ──
          ResponseAnalyticsTab(formId: widget.formId, title: widget.title),
          // ── Tab Respon: daftar responden (isi lama screen ini) ──
          _buildResponTab(),
        ],
      ),
      ),
    ),
    );
  }

  /// Isi tab Respon: satu ListView langsung (tanpa Column+Expanded)
  /// agar cocok sebagai child TabBarView di dalam NestedScrollView.
  Widget _buildResponTab() {
    if (_loading && _analytics == null) {
      return const LoadingOverlay(contained: true);
    }
    return AbsorbPointer(
      absorbing: _exporting,
      child: AuthBackground(
        plain: true,
        child: SafeArea(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical &&
                  n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                _loadMore();
              }
              return false;
            },
            child: ListView(
              controller: _responScrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (_exporting)
                  const progress.ProgressIndicator.linear(
                      semanticsLabel: 'Mengekspor respon'),
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
                    if (_groupedRespondents.isEmpty)
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
                      for (var i = 0; i < _groupedRespondents.length; i++) ...[
                        AnalyticsRespondentCard(
                          index: i,
                          respondent: _groupedRespondents[i].latest,
                          attemptCount: _groupedRespondents[i].attempts.length,
                          onTap: () => _openRespondent(_groupedRespondents[i].latest),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: LoadingIndicator.inline()),
                        ),
                      // Pagination hanya jika group by user > 20
                      if (_showPagination)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                onPressed: _page > 1 && !_loading && !_loadingMore ? () => _goToPage(_page - 1) : null,
                                icon: const Icon(Icons.chevron_left, size: 22),
                              ),
                              Text('Halaman $_page dari $_totalPages', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: kFontBold, color: Colors.black87)),
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                onPressed: _page < _totalPages && !_loading && !_loadingMore ? () => _goToPage(_page + 1) : null,
                                icon: const Icon(Icons.chevron_right, size: 22),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
  }
}


/// Tab Analisis/Respon bergaya Riwayat/Responden (teks + underline teal).
class _MintTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  const _MintTabBar({required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kAppBg,
        border: Border(
          bottom: BorderSide(color: Color(0xCCBDC9C8)),
        ),
      ),
      child: TabBar(
        controller: controller,
        labelColor: kPrimary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: kPrimary,
        indicatorWeight: 2.5,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.bold, fontFamily: kFontBold, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: const [Tab(text: 'Analisis'), Tab(text: 'Respon')],
      ),
    );
  }
}


class _GroupedRespondent {
  final String displayName;
  final RespondentAnalyticsData latest;
  final List<RespondentAnalyticsData> attempts;
  _GroupedRespondent({required this.displayName, required this.latest, required this.attempts});
}
