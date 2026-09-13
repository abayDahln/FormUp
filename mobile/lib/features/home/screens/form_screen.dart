import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/form_card.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/network_status.dart';
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
    NetworkStatus.onlineTick.addListener(_onOnline);
    _loadMyForms();
  }

  void _onOnline() {
    if (mounted && NetworkStatus.isOnline) _refreshMyForms();
  }

  @override
  void dispose() {
    formsVersion.removeListener(_refreshMyForms);
    NetworkStatus.onlineTick.removeListener(_onOnline);
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
    await AdaptiveSheet.show<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext, _) => FormFilterSheetContent(
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
    final cs = Theme.of(context).colorScheme;
    final all = _filtered;
    final hasFilter = _searchQuery.isNotEmpty ||
        _filterDate != null ||
        _sort != FormSort.newest;

    return AppRefreshIndicator(
      onRefresh: _loadMyForms,
      indicatorColor: cs.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: isDesktopWidth(context)
            ? const EdgeInsets.fromLTRB(32, 28, 32, 32)
            : centerPad(
                context,
                base: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Form Saya',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                          color: cs.onSurface,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Lihat dan Kelola Form Anda',
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                // 3b: desktop — tombol di header (ganti FAB melayang).
                if (isDesktopWidth(context)) ...[
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => AppRouter.of(context)
                        .push(AppPage.formTemplateChooser),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Buat Form Baru'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // 3c: desktop — search 480px + tombol filter, full width between.
            if (isDesktopWidth(context))
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Flexible + maxWidth: selebar 480 bila muat, menyusut
                  // mengikuti ruang (anti-overflow saat window dikecilkan).
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: FormSearchBar(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: _onSearchImmediate,
                        onClearSearch: () {
                          _searchController.clear();
                          _onSearchImmediate('');
                        },
                        filterActive:
                            _filterDate != null || _sort != FormSort.newest,
                        onOpenFilter: _openFilterSheet,
                        historyKey: 'search_history_form',
                        inlineFilter: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: _openFilterSheet,
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(
                      (_filterDate != null || _sort != FormSort.newest)
                          ? 'Filter aktif'
                          : 'Filter',
                    ),
                  ),
                ],
              )
            else
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
            // Mobile 1 kolom, tablet/desktop 2/3/4 (min 2, max 4).
            else
              ResponsiveGrid(
                columnCountFor: (w) =>
                    w >= 1400 ? 4 : w >= 840 ? 3 : w >= 600 ? 2 : 1,
                children: [
                  for (final form in all) _buildFormCard(form),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
