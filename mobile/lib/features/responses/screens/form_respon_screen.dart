import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:form_up/core/widgets/loading_indicator.dart';
import 'package:form_up/core/widgets/progress_indicator.dart' as progress;
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/widgets/empty_state.dart';
import 'package:form_up/core/widgets/connection_error_view.dart';
import 'package:form_up/core/widgets/loading_skeleton.dart';
import 'package:form_up/core/widgets/app_toast.dart' hide showAuthToast;
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/network_status.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/responses/widgets/response_analytics_tab.dart';
import 'package:form_up/features/responses/widgets/response_list_card.dart';
import 'package:form_up/features/form/widgets/exam_monitoring_panel.dart';

/// Kelola respon form — 3 tab: Analisis (ringkasan persen/diagram seperti
/// versi web), Respon (daftar respon), dan Monitoring (pantauan live
/// peserta — berlaku untuk formulir maupun ujian).
class FormResponScreen extends StatefulWidget {
  final int formId;
  final String title;

  /// Tab awal: 0 = Analisis, 1 = Respon, 2 = Monitoring.
  final int initialTab;

  const FormResponScreen({
    super.key,
    required this.formId,
    required this.title,
    this.initialTab = 0,
  });

  @override
  State<FormResponScreen> createState() => _FormResponScreenState();
}

class _FormResponScreenState extends State<FormResponScreen>
    with SingleTickerProviderStateMixin {
  static const _pageSize = 10;
  late final TabController _tabController;
  List<ResponseListItemData> _responses = [];
  bool _loading = true;
  String? _loadError;
  bool _loadingMore = false;
  bool _exporting = false;
  bool _hasMore = true;
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    NetworkStatus.onlineTick.addListener(_onOnline);
    _load();
  }

  void _onOnline() {
    if (mounted && NetworkStatus.isOnline) _load();
  }

  @override
  void dispose() {
    NetworkStatus.onlineTick.removeListener(_onOnline);
    _tabController.dispose();
    super.dispose();
  }

  /// Context list respon (di dalam NestedScrollView) untuk akses primary
  /// scroll controller bawaan NestedScrollView saat kembali ke atas.
  BuildContext? _listContext;

  void _scrollListToTop() {
    final ctx = _listContext;
    if (ctx != null && ctx.mounted) {
      PrimaryScrollController.maybeOf(ctx)?.jumpTo(0);
    }
  }

  Future<void> _load({bool refresh = false}) => _loadPage(1, refresh: refresh);

  Future<void> _loadPage(int page, {bool refresh = false}) async {
    setState(() {
      _loading = true;
      _page = page;
      _hasMore = true;
      _loadError = null;
    });
    try {
      final result = await FormService.getResponses(
        widget.formId,
        page: page,
        pageSize: _pageSize,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() {
        _responses = result.items;
        _total = result.total;
        _hasMore = _responses.length < result.total;
        _loadError = null;
      });
      _scrollListToTop();
    } catch (e) {
      if (!mounted) return;
      if (AuthService.isConnectionError(e)) {
        setState(() => _loadError = AuthService.errorMessage(e));
        return;
      }
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
      final result = await FormService.getResponses(
        widget.formId,
        page: next,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = next;
        _responses = [..._responses, ...result.items];
        _total = result.total;
        _hasMore = _responses.length < result.total;
      });
    } catch (e) {
      // ponytail: load-more gagal tanpa toast
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openDetail(ResponseListItemData response) {
    if (_exporting) return;
    AppRouter.of(context).push(AppPage.respondentDetail, {
      'formId': widget.formId,
      'title': widget.title,
      'responseId': response.id,
      'respondentName': response.respondentName ?? '',
    });
  }

  Future<String?> _pickExportFormat() => AdaptiveSheet.show<String>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx, _) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Text('Pilih format ekspor', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold)),
            const SizedBox(height: 8),
            for (final f in ['csv', 'xlsx', 'pdf'])
              ListTile(
                leading: Icon(f == 'pdf' ? Icons.picture_as_pdf_outlined : f == 'xlsx' ? Icons.table_chart_outlined : Icons.description_outlined, color: Theme.of(ctx).colorScheme.primary),
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
    await SharePlus.instance.share(ShareParams(files: [xfile], text: 'Export respon ${widget.title} ($format)'));
  }

  Future<void> _showExportDoneDialog(Uint8List bytes, String fileName, String mime, String format) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ResponsiveDialog(
        child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:  Row(children: [Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary), SizedBox(width: 8), Text('Ekspor Selesai', style: TextStyle(fontFamily: kFontBold))]),
        content: Text('File "$fileName" berhasil dibuat (${(bytes.length / 1024).toStringAsFixed(1)} KB).', style:  TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          FilledButton.icon(onPressed: () async { Navigator.pop(ctx); await _shareExport(bytes, fileName, mime, format); }, icon: const Icon(Icons.share_outlined, size: 18), label: const Text('Bagikan')),
        ],
        ),
      ),
    );
  }

  Future<void> _export() async {
    if (_exporting || _responses.isEmpty) return;
    final format = await _pickExportFormat();
    if (format == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final bytes = await FormService.exportResponses(widget.formId, format: format);
      if (!mounted) return;
      final mime = format == 'xlsx' ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' : format == 'pdf' ? 'application/pdf' : 'text/csv';
      final sanitized = _sanitizeFileName(widget.title);
      final fileName = '$sanitized.$format';
      await _showExportDoneDialog(bytes, fileName, mime, format);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_exporting,
      onPopInvokedWithResult: (didPop, _) { if (!didPop && _exporting) showAppToast(context, 'Tunggu ekspor selesai', type: ToastType.warning); },
      child: Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape:  Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
        leading: IconButton(
          icon:  Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: _exporting ? null : () => AppRouter.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style:  TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _exporting
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: LoadingIndicator.inline(),
                    ),
                  )
                : IconButton(
                    icon:  Icon(Icons.download_outlined, color: cs.onSurface),
                    tooltip: 'Export CSV/XLSX/PDF',
                    onPressed: _responses.isEmpty || _exporting ? null : _export,
                  ),
          ),
        ],
      ),
      body: NestedScrollView(
        // Tab bar ikut tergulung bersama konten (bukan fixed di appbar).
        headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: _MintTabBar(controller: _tabController),
                  ),
                ),
              ),
            ],
        body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab Analisis ──
          ResponseAnalyticsTab(formId: widget.formId, title: widget.title),
          // ── Tab Respon (daftar respon seperti sebelumnya) ──
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical &&
                  n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                _loadMore();
              }
              return false;
            },
            child: Column(children: [
            if (_exporting) const progress.ProgressIndicator.linear(semanticsLabel: 'Mengekspor respon'),
            Expanded(child: _loading
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: centerPad(context,
                      base: const EdgeInsets.fromLTRB(20, 12, 20, 24)),
                  child: const SkeletonList.responses(itemCount: 5),
                )
              : AbsorbPointer(
                  absorbing: _exporting,
                  child: AuthBackground(plain: true,
                  child: SafeArea(
                    child: _responses.isEmpty
                        ? AppRefreshIndicator(
                            onRefresh: () => _load(refresh: true),
                            indicatorColor: cs.primary,
                            child: SingleChildScrollView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding: centerPad(context,
                                  base: const EdgeInsets.fromLTRB(
                                      20, 12, 20, 24)),
                              child: _loadError != null
                                  ? ConnectionErrorView(
                                      message: _loadError!,
                                      onRetry: () =>
                                          _load(refresh: true),
                                    )
                                  : const EmptyState(
                                      icon: Icons.inbox_outlined,
                                      title: 'Belum ada respons',
                                      message:
                                          'Bagikan form agar responden dapat mulai mengisi.',
                                    ),
                            ),
                          )
                        : AppRefreshIndicator(
                            onRefresh: () => _load(refresh: true),
                            indicatorColor: cs.primary,
                            child: Builder(builder: (listCtx) {
                              _listContext = listCtx;
                              return ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: centerPad(context, base: const EdgeInsets.fromLTRB(20, 12, 20, 24)),
                              itemCount: _responses.length + 1,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                if (i >= _responses.length) {
                                  if (_loadingMore) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    );
                                  }
                                  final totalPages = (_total / _pageSize).ceil().clamp(1, 999);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    // Pagination dipusatkan (maks 480) agar tak melar.
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 480),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        IconButton.filledTonal(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: _page > 1 && !_loading ? () => _loadPage(_page - 1) : null,
                                          icon: const Icon(Icons.chevron_left, size: 22),
                                        ),
                                        Text('Halaman $_page dari $totalPages', style:  TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: kFontBold, color: cs.onSurface)),
                                        IconButton.filledTonal(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: _page < totalPages && !_loading ? () => _loadPage(_page + 1) : null,
                                          icon: const Icon(Icons.chevron_right, size: 22),
                                        ),
                                          ],
                                        ),
                                        ),
                                      ),
                                  );
                                }
                                return ResponseListCard(
                                  response: _responses[i],
                                  index: i,
                                  onOpenDetail: () => _openDetail(_responses[i]),
                                );
                              },
                              );
                            }),
                        ),
                  ),
                ),
              ),
            ),
          ],
          ),
          ),
          // ── Tab Monitoring (pantauan live, formulir & ujian) ──
          ExamMonitoringPanel(formId: widget.formId),
        ],
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
      color: Theme.of(context).scaffoldBackgroundColor,
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

