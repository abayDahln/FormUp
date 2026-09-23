import 'dart:async';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:form_up/core/widgets/ai_chat_icon.dart';
import 'package:form_up/core/widgets/loading_indicator.dart';
import 'package:form_up/core/widgets/connection_error_view.dart';
import 'package:form_up/core/widgets/loading_skeleton.dart';
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/widgets/progress_indicator.dart' as progress;
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
import 'package:form_up/features/form/widgets/exam_monitoring_panel.dart';

/// Analisis respons form - 3 tab: Analisis (diagram persen seperti web),
/// Respon (daftar responden), dan Monitoring (pantauan live peserta).
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
  final _searchController = TextEditingController();
  late final TabController _tabController =
      TabController(length: 3, vsync: this);
  Timer? _debounce;
  String _query = '';
  FormAnalytics? _analytics;
  List<RespondentAnalyticsData> _respondents = [];
  bool _loading = true;
  String? _loadError;
  bool _exporting = false;
  _RespondentSort _sort = _RespondentSort.newest;

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

  /// Controller list tab Respon.
  final _responScrollController = ScrollController();

  Future<void> _load({bool refresh = false}) async {
    if (widget.formId == 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      // Muat SEMUA halaman (pageSize 100) lalu group by user di klien.
      // Backend selalu paged (default 20) sehingga hitung badge "Nx
      // percobaan" dari satu halaman saja berubah-ubah saat scroll
      // (_loadMore menambah data → count naik; ganti halaman → recount).
      final all = <RespondentAnalyticsData>[];
      FormAnalytics? first;
      var page = 1;
      const fetchSize = 100;
      while (true) {
        final analytics = await FormService.getAnalytics(
          widget.formId,
          page: page,
          pageSize: fetchSize,
          search: _query,
          refresh: refresh || page > 1,
        );
        first ??= analytics;
        all.addAll(analytics.respondents);
        final total = analytics.totalResponses;
        if (all.length >= total || analytics.respondents.isEmpty) break;
        page++;
        if (page > 50) break; // pengaman: maks 5000 respon
      }
      if (!mounted) return;
      setState(() {
        _analytics = first;
        _respondents = all;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (AuthService.isConnectionError(e)) {
        setState(() {
          _loadError = AuthService.errorMessage(e);
          _analytics ??= const FormAnalytics();
          _respondents = _respondents.isEmpty ? const [] : _respondents;
        });
        return;
      }
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
      setState(() {
        _analytics ??= const FormAnalytics();
        _respondents = _respondents.isEmpty ? const [] : _respondents;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Semua data sudah dimuat penuh di [_load] (lalu di-group by user),
  /// jadi scroll ke bawah tidak perlu mengambil halaman lanjutan.
  Future<void> _loadMore() async {
    return;
  }

  /// Satu grup responden (hasil group-by user): [representative] adalah
  /// respon TERBARU grup itu (yang dibuka saat kartu diketuk — screen detail
  /// memuat semua attempt via getRespondentAttempts), [count] total
  /// pengerjaan grup. Dihitung dari data penuh sehingga badge stabil.
  List<({RespondentAnalyticsData representative, int count})>
      get _groupedRespondents {
    final map = <String, List<RespondentAnalyticsData>>{};
    for (final r in _respondents) {
      final name = (r.respondentName ?? '').trim().toLowerCase();
      // Nama kosong = identitas tak dikenal → tiap respon baris sendiri.
      final key = name.isEmpty ? '__anon:${r.responseId}' : 'name:$name';
      map.putIfAbsent(key, () => []).add(r);
    }
    final groups = <({RespondentAnalyticsData representative, int count})>[];
    for (final entry in map.entries) {
      final attempts = entry.value
        ..sort((a, b) {
          final c = b.submittedAt.compareTo(a.submittedAt);
          if (c != 0) return c;
          return b.responseId.compareTo(a.responseId);
        });
      groups.add((representative: attempts.first, count: attempts.length));
    }
    return groups;
  }

  List<({RespondentAnalyticsData representative, int count})>
      get _sortedRespondents {
    final list = _groupedRespondents;
    switch (_sort) {
      case _RespondentSort.newest:
        // Urut per-grup berdasar respon terbaru grup (tie-break responseId
        // agar stabil bila timestamp sama).
        list.sort((a, b) {
          final c = b.representative.submittedAt
              .compareTo(a.representative.submittedAt);
          if (c != 0) return c;
          return b.representative.responseId
              .compareTo(a.representative.responseId);
        });
        break;
      case _RespondentSort.oldest:
        list.sort((a, b) {
          final c = a.representative.submittedAt
              .compareTo(b.representative.submittedAt);
          if (c != 0) return c;
          return a.representative.responseId
              .compareTo(b.representative.responseId);
        });
        break;
      case _RespondentSort.highScore:
        list.sort((a, b) {
          final c = (b.representative.score ?? -1)
              .compareTo(a.representative.score ?? -1);
          if (c != 0) return c;
          final t = b.representative.submittedAt
              .compareTo(a.representative.submittedAt);
          if (t != 0) return t;
          return b.representative.responseId
              .compareTo(a.representative.responseId);
        });
        break;
      case _RespondentSort.lowScore:
        list.sort((a, b) {
          final c = (a.representative.score ?? 999)
              .compareTo(b.representative.score ?? 999);
          if (c != 0) return c;
          final t = a.representative.submittedAt
              .compareTo(b.representative.submittedAt);
          if (t != 0) return t;
          return a.representative.responseId
              .compareTo(b.representative.responseId);
        });
        break;
    }
    return list;
  }

  /// Daftar tampil tab Respon: 1 kartu per user (group by nama).
  /// Detail attempt dibuka lewat kartu (respon terbaru grup).
  List<({RespondentAnalyticsData representative, int count})>
      get _visibleRespondents => _sortedRespondents;

  void _openRespondent(RespondentAnalyticsData respondent) {
    if (_exporting) return;
    AppRouter.of(context).push(AppPage.respondentDetail, {
      'formId': widget.formId,
      'title': widget.title,
      'responseId': respondent.responseId,
      'respondentName': respondent.respondentName ?? '',
    });
  }

  /// Controller menu urut (M3 MenuAnchor): posisi otomatis mengikuti field
  /// pencarian â€” pengganti showMenu berposisi hardcoded yang nyasar di 1920.
  final _sortMenuController = MenuController();

  Future<String?> _pickExportFormat() => AdaptiveSheet.show<String>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx, _) {
          final cs = Theme.of(ctx).colorScheme;
          return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text('Pilih format ekspor', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold, color: cs.onSurface)),
            const SizedBox(height: 8),
            for (final f in ['csv', 'xlsx', 'pdf'])
              ListTile(
                leading: Icon(f == 'pdf' ? Icons.picture_as_pdf_outlined : f == 'xlsx' ? Icons.table_chart_outlined : Icons.description_outlined, color: cs.primary),
                title: Text(f.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold)),
                onTap: () => Navigator.pop(ctx, f),
              ),
            const SizedBox(height: 8),
          ]),
        );
        },
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
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return ResponsiveDialog(
        child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.check_circle, color: cs.primary), const SizedBox(width: 8), const Text('Ekspor Selesai', style: TextStyle(fontFamily: kFontBold))]),
        content: Text('File "$fileName" berhasil dibuat (${(bytes.length / 1024).toStringAsFixed(1)} KB).', style: TextStyle(fontSize: 13, color: cs.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          FilledButton.icon(onPressed: () async { Navigator.pop(ctx); await _shareExport(bytes, fileName, mime, format); }, icon: const Icon(Icons.share_outlined, size: 18), label: const Text('Bagikan')),
        ],
        ),
      );
      },
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
  /// (seperti Analisis AI di web â€” user yang menekan kirim sendiri).
  void _openAiAnalysis() {
    if (_exporting || widget.formId == 0) return;
    AppRouter.of(context).push(AppPage.aiChat, {
      'formId': widget.formId,
      'initialPrompt': _buildAiPrompt(),
    });
  }

  /// Prompt analisis hasil form â€” ringkasan data + instruksi analisis
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
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_exporting,
      onPopInvokedWithResult: (didPop, _) { if (!didPop && _exporting) showAppToast(context, 'Tunggu ekspor selesai', type: ToastType.warning); },
      child: Scaffold(
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
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: _exporting ? null : () => AppRouter.of(context).pop(),
        ),
        title: const Text(
          "Responden",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
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
                    icon: Icon(Icons.download_outlined, color: cs.onSurface),
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
          // â”€â”€ Tab Analisis: diagram persen & analisis mendetail â”€â”€
          ResponseAnalyticsTab(formId: widget.formId, title: widget.title),
          _buildResponTab(),
          // ── Tab Monitoring (pantauan live, formulir & ujian) ──
          ExamMonitoringPanel(formId: widget.formId),
          ],
      ),
      ),
    ),
    );
  }

  /// Isi tab Respon: satu ListView langsung (tanpa Column+Expanded)
  /// agar cocok sebagai child TabBarView di dalam NestedScrollView.
  Widget _buildResponTab() {
    final cs = Theme.of(context).colorScheme;
    if (_loading && _analytics == null) {
      // Mirror layout asli: kartu judul + baris ringkasan + kartu responden.
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: centerPad(context,
            base: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            wideMaxWidth: 1100),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonTitleCard(),
            SizedBox(height: 16),
            SkeletonSummaryRow(),
            SizedBox(height: 16),
            SkeletonList.respondents(itemCount: 4),
          ],
        ),
      );
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
            child: AppRefreshIndicator(
              onRefresh: () => _load(refresh: true),
              indicatorColor: cs.primary,
              child: ListView(
                controller: _responScrollController,
                padding: centerPad(context, base: const EdgeInsets.fromLTRB(20, 16, 20, 24), wideMaxWidth: 1100),
              children: [
                if (_exporting)
                  const progress.ProgressIndicator.linear(
                      semanticsLabel: 'Mengekspor respon'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: softShadow(),
                      ),
                      child: RichTextView(
                        text: widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_analytics != null)
                      AnalyticsSummaryRow(analytics: _analytics!),
                    const SizedBox(height: 16),
                    MenuAnchor(
                      controller: _sortMenuController,
                      menuChildren: [
                        for (final s in _RespondentSort.values)
                          MenuItemButton(
                            leadingIcon: Icon(s.icon,
                                size: 18,
                                color: _sort == s
                                    ? cs.primary
                                    : cs.onSurfaceVariant),
                            onPressed: () =>
                                setState(() => _sort = s),
                            child: Text(s.label,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: _sort == s
                                        ? cs.primary
                                        : cs.onSurface,
                                    fontWeight: _sort == s
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                          ),
                      ],
                      child: AppSearchField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: _onSearchImmediate,
                        hint: 'Cari responden...',
                        historyKey: 'search_history_analytics',
                        filterActive: _sort != _RespondentSort.newest,
                        onOpenFilter: () {
                          if (_exporting) return;
                          _sortMenuController.open();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Responden",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadError != null &&
                        _visibleRespondents.isEmpty &&
                        _query.isEmpty)
                      ConnectionErrorView(
                        message: _loadError!,
                        onRetry: () => _load(refresh: true),
                        bare: true,
                      )
                    else if (_visibleRespondents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, color: cs.onSurfaceVariant, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty
                                  ? 'Belum ada responden'
                                  : 'Tidak ada hasil untuk "${_searchController.text}"',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    else if (!isExpanded(context)) ...[
                      for (var i = 0; i < _visibleRespondents.length; i++) ...[
                        AnalyticsRespondentCard(
                          index: i,
                          respondent:
                              _visibleRespondents[i].representative,
                          attemptCount:
                              _visibleRespondents[i].count,
                          onTap: () => _openRespondent(
                            _visibleRespondents[i].representative,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Ringkasan grup: X responden • Y respons.
                      Center(
                        child: Text(
                          '${_visibleRespondents.length} responden • ${_respondents.length} respons',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      // Tablet/desktop: responden 2 kolom.
                    ] else ...[
                      ResponsiveGrid(
                        columnCountFor: (_) => 2,
                        children: [
                          for (var i = 0; i < _visibleRespondents.length; i++)
                            AnalyticsRespondentCard(
                              index: i,
                              respondent: _visibleRespondents[i]
                                  .representative,
                              attemptCount:
                                  _visibleRespondents[i].count,
                              onTap: () => _openRespondent(
                                _visibleRespondents[i].representative,
                              ),
                            ),
                        ],
                      ),
                      // Ringkasan grup: X responden • Y respons.
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Center(
                          child: Text(
                            '${_visibleRespondents.length} responden • ${_respondents.length} respons',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      // Pagination dihapus: daftar group dihitung dari data penuh.
                    ],
                  ],
                ),
              ),
              ),
            ),
          ),
        );
  }
}


/// Tab Analisis/Respon/Monitoring bergaya Riwayat/Responden (teks + underline teal).
class _MintTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  const _MintTabBar({required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: TabBar(
        controller: controller,
        labelColor: cs.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: cs.primary,
        indicatorWeight: 2.5,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.bold, fontFamily: kFontBold, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: const [Tab(text: 'Analisis'), Tab(text: 'Respon'), Tab(text: 'Monitoring')],
      ),
    );
  }
}

