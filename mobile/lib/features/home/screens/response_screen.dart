import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/search_field.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/home/widgets/response_analytics_card.dart';
import 'package:form_up/features/home/widgets/response_empty_state.dart';
import 'package:form_up/features/home/widgets/response_history_group_card.dart';


/// Tab Respons: riwayat & analisis
class ResponseScreen extends StatefulWidget {
  const ResponseScreen({super.key});

  @override
  State<ResponseScreen> createState() => _ResponseScreenState();
}

class _ResponseScreenState extends State<ResponseScreen> {
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
    return DefaultTabController(
      length: 2,
      child: SafeArea(
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppSearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                hint: 'Cari respons...',
              ),
            ),
            const SizedBox(height: 14),
            const ColoredBox(
              color: Colors.white,
              child: TabBar(
                labelColor: kPrimary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: kPrimary,
                indicatorWeight: 2.5,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold, fontSize: 13),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: [
                  Tab(text: 'Riwayat'),
                  Tab(text: 'Analisis'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading && _history.isEmpty && _myForms.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildHistoryList(),
                        _buildAnalyticsList(),
                      ],
                    ),
            ),
          ],
        ),
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
    if (groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: kAuthPrimary,
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
                        _query.isEmpty ? 'Belum ada riwayat pengerjaan' : 'Tidak ada hasil untuk "${_searchController.text}"',
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
    return RefreshIndicator(
      onRefresh: _load,
      color: kAuthPrimary,
      child: ListView.builder(
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
    if (forms.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: kAuthPrimary,
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
                        _query.isEmpty ? 'Belum ada form untuk dianalisis' : 'Tidak ada hasil untuk "${_searchController.text}"',
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
    return RefreshIndicator(
      onRefresh: _load,
      color: kAuthPrimary,
      child: ListView.builder(
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
