import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'rich_editor.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';
import '../app_router.dart';

/// Status respons yang bisa diubah pemilik form (ID referensi ResponseStatus).
const _statusOptions = <(int, String)>[
  (1, 'New'),
  (2, 'Reviewed'),
  (3, 'Accepted'),
  (4, 'Rejected'),
];

int _statusIdOf(String? status) {
  switch (status?.toLowerCase()) {
    case 'reviewed':
      return 2;
    case 'accepted':
      return 3;
    case 'rejected':
      return 4;
    default:
      return 1;
  }
}

(String, Color, Color) _statusStyle(String status) {
  switch (status.toLowerCase()) {
    case 'reviewed':
      return ('Reviewed', const Color(0xFFB26A00), const Color(0xFFFFF3DE));
    case 'accepted':
      return ('Accepted', const Color(0xFF2E7D32), const Color(0xFFE3F4E8));
    case 'rejected':
      return ('Rejected', const Color(0xFFC0392B), const Color(0xFFFDE8E6));
    default:
      return ('New', const Color(0xFF2E7D32), const Color(0xFFE3F4E8));
  }
}

/// Kelola respons form milik sendiri: daftar, detail, dan ubah status.
class FormResponsesScreen extends StatefulWidget {
  final int formId;
  final String title;

  const FormResponsesScreen({
    super.key,
    required this.formId,
    required this.title,
  });

  @override
  State<FormResponsesScreen> createState() => _FormResponsesScreenState();
}

class _FormResponsesScreenState extends State<FormResponsesScreen> {
  static const _pageSize = 20;
  final _scrollController = ScrollController();
  List<ResponseListItemData> _responses = [];
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
      final result = await FormService.getResponses(
        widget.formId,
        page: 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _responses = result.items;
        _hasMore = result.items.length < result.total;
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
      final result = await FormService.getResponses(
        widget.formId,
        page: next,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = next;
        _responses = [..._responses, ...result.items];
        _hasMore = result.items.length < result.total;
      });
    } catch (e) {
      // ponytail: gagal load-more tidak perlu toast keras; user bisa scroll lagi.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _changeStatus(int responseId, int statusId) async {
    try {
      await FormService.updateResponseStatus(responseId, statusId);
      if (!mounted) return;
      final label =
          _statusOptions.firstWhere((s) => s.$1 == statusId).$2.toLowerCase();
      setState(() {
        _responses = [
          for (final r in _responses)
            if (r.id == responseId)
              ResponseListItemData(
                id: r.id,
                respondentName: r.respondentName,
                status: label,
                submittedAt: r.submittedAt,
              )
            else
              r,
        ];
      });
      showAuthToast(context, 'Status diperbarui');
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthBg,
      appBar: AppBar(
        backgroundColor: kAuthBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(fontFamily: kFontBold, color: Colors.black87),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AuthBackground(
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
                                'Belum ada respons.',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: kAuthPrimary,
                        child: ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          itemCount: _responses.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            if (i >= _responses.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            return _buildResponseCard(_responses[i], i);
                          },
                        ),
                      ),
              ),
            ),
    );
  }

  Widget _buildResponseCard(ResponseListItemData r, int index) {
    final style = _statusStyle(r.status);
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
          r.submittedAt == null
              ? 'Waktu tidak diketahui'
              : _formatTime(r.submittedAt!),
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        trailing: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _statusIdOf(r.status),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            items: [
              for (final s in _statusOptions)
                DropdownMenuItem(value: s.$1, child: Text(s.$2)),
            ],
            onChanged: (v) {
              if (v != null) _changeStatus(r.id, v);
            },
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: style.$2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    style.$1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: style.$3,
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => _openDetail(r.id),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kAuthPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text(
                    'Lihat Jawaban',
                    style: TextStyle(color: kAuthPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(int responseId) async {
    try {
      final detail = await FormService.getResponseDetail(
        widget.formId,
        responseId,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _ResponseDetailSheet(detail: detail),
      );
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return "${local.day}/${local.month}/${local.year} $hh:$mm";
  }
}

class _ResponseDetailSheet extends StatelessWidget {
  final ResponseDetailData detail;

  const _ResponseDetailSheet({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (detail.respondentName ?? '').trim().isEmpty
                            ? 'Detail Respons'
                            : detail.respondentName!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                          color: Colors.black87,
                        ),
                      ),
                      if (detail.submittedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatDetailTime(detail.submittedAt!),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: detail.answers.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada jawaban.',
                      style: TextStyle(fontSize: 13, color: Colors.black45),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: detail.answers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final a = detail.answers[i];
                      final answered = a.display.trim().isNotEmpty;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichTextView(
                              text: a.question,
                              prefix: '${i + 1}. ',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: kFontBold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              answered ? a.display : 'Tidak dijawab',
                              style: TextStyle(
                                fontSize: 12,
                                color: answered
                                    ? Colors.black87
                                    : Colors.black45,
                                fontStyle: answered
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDetailTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return "${local.day}/${local.month}/${local.year} $hh:$mm";
  }
}
