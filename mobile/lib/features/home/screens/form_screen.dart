import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/form_card.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/home/controllers/form_sort_filter.dart';
import 'package:form_up/features/home/widgets/form_empty_state.dart';
import 'package:form_up/features/home/widgets/form_filter_sheet_content.dart';
import 'package:form_up/features/home/widgets/form_search_bar.dart';

/// Tab Form: kelola form saya
class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  List<FormData> _myForms = [];
  bool _loadingForms = true;
  DateTime _lastRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  DateTime? _filterDate;
  FormSort _sort = FormSort.newest;
  bool _filterOpen = false;

  @override
  void initState() {
    super.initState();
    formsVersion.addListener(_refreshMyForms);
    _loadMyForms();
  }

  @override
  void dispose() {
    formsVersion.removeListener(_refreshMyForms);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMyForms() async {
    // ponytail: debounce refresh 2 detik
    final now = DateTime.now();
    if (now.difference(_lastRefresh) < const Duration(seconds: 2)) return;
    _lastRefresh = now;
    await _refreshMyForms();
  }

  /// Muat ulang (tanpa debounce)
  Future<void> _refreshMyForms() async {
    setState(() => _loadingForms = true);
    try {
      final forms = await FormService.getMyForms();
      if (!mounted) return;
      setState(() => _myForms = forms);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loadingForms = false);
    }
  }

  void _onSearchImmediate(String value) {
    _debounce?.cancel();
    if (!mounted) return;
    setState(() => _searchQuery = value.trim().toLowerCase());
  }

  /// Cari (debounce 500ms)
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value;
      });
    });
  }

  /// Hasil filter & urutan
  List<FormData> get _filtered =>
      filterForms(_myForms, _searchQuery, _filterDate, _sort);

  Future<void> _openFilterSheet() async {
    if (_filterOpen) return;
    _filterOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => FormFilterSheetContent(
        filterDate: _filterDate,
        sortIndex: _sort.index,
        onPickDate: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _filterDate ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (picked == null || !sheetContext.mounted) return;
          Navigator.pop(sheetContext);
          setState(() {
            _filterDate = picked;
          });
        },
        onClearDate: () {
          Navigator.pop(sheetContext);
          setState(() {
            _filterDate = null;
          });
        },
        onSortSelected: (v) {
          Navigator.pop(sheetContext);
          setState(() {
            _sort = FormSort.values[v];
          });
        },
        onReset: () {
          Navigator.pop(sheetContext);
          setState(() {
            _filterDate = null;
            _sort = FormSort.newest;
          });
        },
      ),
    ).whenComplete(() => _filterOpen = false);
  }

  Widget _buildFormCard(FormData form) {
    return FormCard(
      form: form,
      onTap: () => AppRouter.of(context).push(AppPage.formDetail, {
        'formId': form.id,
        'form': form,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _filtered;
    final hasFilter = _searchQuery.isNotEmpty ||
        _filterDate != null ||
        _sort != FormSort.newest;

    return AppRefreshIndicator(
      onRefresh: _loadMyForms,
      indicatorColor: kAuthPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Form Saya',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Lihat dan Kelola Form Anda',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 16),

            FormSearchBar(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchImmediate,
              onClearSearch: () {
                _searchController.clear();
                _onSearchImmediate('');
              },
              filterActive: _filterDate != null || _sort != FormSort.newest,
              onOpenFilter: _openFilterSheet,
              historyKey: 'search_history_form',
            ),
            const SizedBox(height: 16),

            if (_loadingForms && _myForms.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: AppLoadingOverlay(),
              )
            else if (all.isEmpty)
              FormEmptyState(hasFilter: hasFilter)
            else ...[
              for (final form in all) ...[
                _buildFormCard(form),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
