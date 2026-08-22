import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/home/widgets/response_analytics_card.dart';
import 'package:form_up/features/home/widgets/response_empty_state.dart';
import 'package:form_up/features/home/widgets/response_history_card.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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

  void _openDetail(MyResponseItem item) {
    AppRouter.of(context).push(AppPage.formHistoryDetail, {
      'formLink': item.formLink,
      'responseId': item.responseId,
    });
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8E2DE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bar_chart,
                    color: kAuthPrimary,
                    size: 20,
                  ),
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

  Widget _buildHistoryList() {
    return RefreshIndicator(
      onRefresh: _load,
      color: kAuthPrimary,
      child: _history.isEmpty
          ? const ResponseEmptyState(
              icon: Icons.history,
              message: 'Belum ada riwayat pengerjaan',
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: _history.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ResponseHistoryCard(
                  item: _history[i],
                  onTap: () => _openDetail(_history[i]),
                ),
              ),
            ),
    );
  }

  Widget _buildAnalyticsList() {
    return RefreshIndicator(
      onRefresh: _load,
      color: kAuthPrimary,
      child: _myForms.isEmpty
          ? const ResponseEmptyState(
              icon: Icons.bar_chart,
              message: 'Belum ada form untuk dianalisis',
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: _myForms.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ResponseAnalyticsCard(
                  form: _myForms[i],
                  onTap: () => _openAnalytics(_myForms[i]),
                ),
              ),
            ),
    );
  }
}
