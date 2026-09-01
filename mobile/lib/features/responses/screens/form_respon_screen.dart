import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:form_up/core/widgets/loading_indicator.dart';
import 'package:form_up/core/widgets/progress_indicator.dart' as progress;
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/widgets/app_toast.dart' hide showAuthToast;
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/network_status.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/responses/widgets/response_list_card.dart';

/// Kelola respon form
class FormResponScreen extends StatefulWidget {
  final int formId;
  final String title;

  const FormResponScreen({
    super.key,
    required this.formId,
    required this.title,
  });

  @override
  State<FormResponScreen> createState() => _FormResponScreenState();
}

class _FormResponScreenState extends State<FormResponScreen> {
  static const _pageSize = 10;
  final _scrollController = ScrollController();
  List<ResponseListItemData> _responses = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _exporting = false;
  bool _hasMore = true;
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    NetworkStatus.onlineTick.addListener(_onOnline);
    _load();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  void _onOnline() {
    if (mounted && NetworkStatus.isOnline) _load();
  }

  @override
  void dispose() {
    NetworkStatus.onlineTick.removeListener(_onOnline);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async => _loadPage(1);

  Future<void> _loadPage(int page) async {
    setState(() {
      _loading = true;
      _page = page;
      _hasMore = true;
    });
    try {
      final result = await FormService.getResponses(
        widget.formId,
        page: page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _responses = result.items;
        _total = result.total;
        _hasMore = _responses.length < result.total;
      });
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
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
    await SharePlus.instance.share(ShareParams(files: [xfile], text: 'Export respon ${widget.title} ($format)'));
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
    return PopScope(
      canPop: !_exporting,
      onPopInvokedWithResult: (didPop, _) { if (!didPop && _exporting) showAppToast(context, 'Tunggu ekspor selesai', type: ToastType.warning); },
      child: Scaffold(
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
          onPressed: _exporting ? null : () => AppRouter.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
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
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: LoadingIndicator.inline(),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_outlined, color: Colors.black87),
                    tooltip: 'Export CSV/XLSX/PDF',
                    onPressed: _responses.isEmpty || _exporting ? null : _export,
                  ),
          ),
        ],
      ),
      body: Column(children: [
        if (_exporting) const progress.ProgressIndicator.linear(semanticsLabel: 'Mengekspor respon'),
        Expanded(child: _loading
          ? const LoadingOverlay(contained: true)
          : AbsorbPointer(
              absorbing: _exporting,
              child: AuthBackground(plain: true,
              child: SafeArea(
                child: _responses.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  color: Colors.grey, size: 36),
                              SizedBox(height: 10),
                              Text(
                                'Belum ada respon.',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      )
                    : AppRefreshIndicator(
                        onRefresh: _load,
                        indicatorColor: kAuthPrimary,
                        child: ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton.filledTonal(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _page > 1 && !_loading ? () => _loadPage(_page - 1) : null,
                                      icon: const Icon(Icons.chevron_left, size: 22),
                                    ),
                                    Text('Halaman $_page dari $totalPages', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: kFontBold, color: Colors.black87)),
                                    IconButton.filledTonal(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _page < totalPages && !_loading ? () => _loadPage(_page + 1) : null,
                                      icon: const Icon(Icons.chevron_right, size: 22),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ResponseListCard(
                              response: _responses[i],
                              index: i,
                              onOpenDetail: () => _openDetail(_responses[i]),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
      ),
    ),
    );
  }
}
