import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/home/widgets/response_analytics_card.dart';
import 'package:form_up/features/home/widgets/response_empty_state.dart';
import 'package:form_up/features/home/widgets/response_history_group_card.dart';
import 'package:form_up/features/home/widgets/response_tab_switcher.dart';

enum _ResponseTab { history, analytics }

/// Tab Respons: riwayat & analisis
class ResponseScreen extends StatefulWidget {
  const ResponseScreen({super.key});

  @override
  State<ResponseScreen> createState() => _ResponseScreenState();
}

class _ResponseScreenState extends State<ResponseScreen> {
  _ResponseTab _tab = _ResponseTab.history;
  List<MyResponseItem> _history = [];
  List<FormData> _myForms = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value.trim().toLowerCase());
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
            child: const Column(
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ResponseTabSwitcher(
              items: const [
                ResponseTabItem(icon: Icons.history, label: 'Riwayat'),
                ResponseTabItem(icon: Icons.bar_chart, label: 'Analisis'),
              ],
              activeIndex: _tab.index,
              onChanged: (i) => setState(() => _tab = _ResponseTab.values[i]),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari respons...',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                prefixIcon: const Icon(Icons.search,
                    color: Colors.black54, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.black54, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7.5),
                  borderSide: const BorderSide(color: Color(0xFF6E7979)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7.5),
                  borderSide: const BorderSide(color: kAuthPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading && _history.isEmpty && _myForms.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : switch (_tab) {
                    _ResponseTab.history => _buildHistoryList(),
                    _ResponseTab.analytics => _buildAnalyticsList(),
                  },
          ),
        ],
      ),
    );
  }

  List<MyResponseItem> get _filteredHistory {
    if (_query.isEmpty) return _history;
    return _history
        .where((e) => e.formTitle.toLowerCase().contains(_query))
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
    return groups.values.toList();
  }

  List<FormData> get _filteredForms {
    if (_query.isEmpty) return _myForms;
    return _myForms
        .where((f) =>
            f.title.toLowerCase().contains(_query) ||
            (f.description ?? '').toLowerCase().contains(_query))
        .toList();
  }

  Widget _buildHistoryList() {
    final groups = _groupedHistory;
    return RefreshIndicator(
      onRefresh: _load,
      color: kAuthPrimary,
      child: groups.isEmpty
          ? ResponseEmptyState(
              icon: Icons.history,
              message: _query.isEmpty
                  ? 'Belum ada riwayat pengerjaan'
                  : 'Tidak ada hasil untuk "${_searchController.text}"',
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: groups.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ResponseHistoryGroupCard(
                  group: groups[i],
                  onTap: () => AppRouter.of(context).push(
                    AppPage.historyFormDetail,
                    {
                      'formLink': groups[i].formLink,
                      'formTitle': groups[i].formTitle,
                    },
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAnalyticsList() {
    final forms = _filteredForms;
    return RefreshIndicator(
      onRefresh: _load,
      color: kAuthPrimary,
      child: forms.isEmpty
          ? ResponseEmptyState(
              icon: Icons.bar_chart,
              message: _query.isEmpty
                  ? 'Belum ada form untuk dianalisis'
                  : 'Tidak ada hasil untuk "${_searchController.text}"',
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: forms.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ResponseAnalyticsCard(
                  form: forms[i],
                  onTap: () => _openAnalytics(forms[i]),
                ),
              ),
            ),
    );
  }
}
