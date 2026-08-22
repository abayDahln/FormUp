import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/responses/widgets/response_list_card.dart';

/// Kelola respons form
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
      // ponytail: load-more gagal tanpa toast
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openDetail(ResponseListItemData response) {
    AppRouter.of(context).push(AppPage.respondentDetail, {
      'formId': widget.formId,
      'title': widget.title,
      'responseId': response.id,
      'respondentName': response.respondentName ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xCCBDC9C8)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => AppRouter.of(context).pop(),
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
    );
  }
}
