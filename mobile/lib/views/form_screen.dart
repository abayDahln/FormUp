import 'dart:async';

import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'form_card.dart';
import 'rich_editor.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';
import '../app_router.dart';

/// Tab "Form" — daftar "Form Saya" (kelola) dengan pencarian, filter, & pagination.
class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

enum _FormSort { newest, oldest, mostResponses, leastResponses }

extension on _FormSort {
  String get label => switch (this) {
        _FormSort.newest => 'Terbaru',
        _FormSort.oldest => 'Terlama',
        _FormSort.mostResponses => 'Respons Terbanyak',
        _FormSort.leastResponses => 'Respons Terdikit',
      };
}

class _FormScreenState extends State<FormScreen> {
  static const _pageSize = 10;

  List<FormData> _myForms = [];
  bool _loadingForms = true;
  DateTime _lastRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  DateTime? _filterDate;
  _FormSort _sort = _FormSort.newest;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _loadMyForms();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMyForms() async {
    // ponytail: debounce — swipe refresh tidak boleh terlalu sering (2 detik).
    final now = DateTime.now();
    if (now.difference(_lastRefresh) < const Duration(seconds: 2)) return;
    _lastRefresh = now;
    await _refreshMyForms();
  }

  /// Muat ulang tanpa debounce — dipakai setelah aksi (mis. publish).
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

  /// Cari dengan debounce 500ms — tanpa perlu tekan Enter.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value;
        _page = 0;
      });
    });
  }

  /// Hasil setelah pencarian + filter tanggal + urutan.
  List<FormData> get _filtered {
    var list = List<FormData>.from(_myForms);

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((f) => richToPlainText(f.title).toLowerCase().contains(q))
          .toList();
    }

    if (_filterDate != null) {
      final target = _filterDate!;
      list = list.where((f) {
        final d = f.createdAt ?? f.updatedAt;
        return d != null &&
            d.year == target.year &&
            d.month == target.month &&
            d.day == target.day;
      }).toList();
    }

    switch (_sort) {
      case _FormSort.newest:
        list.sort((a, b) =>
            (b.createdAt ?? b.updatedAt ?? DateTime(0))
                .compareTo(a.createdAt ?? a.updatedAt ?? DateTime(0)));
      case _FormSort.oldest:
        list.sort((a, b) =>
            (a.createdAt ?? a.updatedAt ?? DateTime(0))
                .compareTo(b.createdAt ?? b.updatedAt ?? DateTime(0)));
      case _FormSort.mostResponses:
        list.sort((a, b) => b.responseCount.compareTo(a.responseCount));
      case _FormSort.leastResponses:
        list.sort((a, b) => a.responseCount.compareTo(b.responseCount));
    }

    return list;
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Filter & Urutkan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black87,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined, color: kAuthPrimary),
              title: Text(
                _filterDate == null
                    ? 'Semua tanggal'
                    : 'Dibuat: ${_formatDate(_filterDate!)}',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              subtitle: const Text(
                'Filter berdasarkan tanggal pembuatan',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              trailing: _filterDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                      tooltip: 'Hapus filter tanggal',
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        setState(() {
                          _filterDate = null;
                          _page = 0;
                        });
                      },
                    )
                  : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
              onTap: () async {
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
                  _page = 0;
                });
              },
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Urutkan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black54,
                ),
              ),
            ),
            RadioGroup<int>(
              groupValue: _sort.index,
              onChanged: (v) {
                if (v == null) return;
                Navigator.pop(sheetContext);
                setState(() {
                  _sort = _FormSort.values[v];
                  _page = 0;
                });
              },
              child: Column(
                children: [
                  for (final s in _FormSort.values)
                    RadioListTile<int>(
                      value: s.index,
                      dense: true,
                      title: Text(
                        s.label,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                ],
              ),
            ),
            if (_filterDate != null || _sort != _FormSort.newest)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    setState(() {
                      _filterDate = null;
                      _sort = _FormSort.newest;
                      _page = 0;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kAuthPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Reset Filter',
                    style: TextStyle(color: kAuthPrimary, fontSize: 13),
                  ),
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(FormData form) {
    return FormCard(
      form: form,
      onTap: () => AppRouter.of(context).push(AppPage.formDetail, {
        'formId': form.id,
        'form': form,
      }),
      onQuickActions: () => showFormQuickActions(
        context,
        form,
        onChanged: _refreshMyForms,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _filtered;
    final totalPages = all.isEmpty ? 1 : (all.length / _pageSize).ceil();
    final page = _page.clamp(0, totalPages - 1);
    final start = page * _pageSize;
    final end = start + _pageSize < all.length ? start + _pageSize : all.length;
    final visible = all.sublist(start, end);
    final hasFilter = _searchQuery.isNotEmpty || _filterDate != null || _sort != _FormSort.newest;

    return RefreshIndicator(
      onRefresh: _loadMyForms,
      color: kAuthPrimary,
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

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    cursorColor: kAuthPrimary,
                    decoration: InputDecoration(
                      hintText: 'Cari form...',
                      hintStyle: const TextStyle(color: kAuthText, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: kAuthText, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF0F4F4),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kAuthPrimary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _filterDate != null || _sort != _FormSort.newest
                        ? kPrimarySoft
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune, color: kAuthPrimary, size: 22),
                    tooltip: 'Filter & urutkan',
                    onPressed: _openFilterSheet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_loadingForms && _myForms.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (all.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(kRadius),
                ),
                child: Column(
                  children: [
                    Icon(
                      hasFilter ? Icons.search_off : Icons.description_outlined,
                      color: Colors.grey,
                      size: 36,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasFilter
                          ? 'Tidak ada form yang cocok.'
                          : 'Belum ada form. Buat form pertama Anda!',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              )
            else ...[
              for (final form in visible) ...[
                _buildFormCard(form),
                const SizedBox(height: 12),
              ],
              if (all.length > _pageSize) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      color: kAuthPrimary,
                      onPressed:
                          page == 0 ? null : () => setState(() => _page = page - 1),
                    ),
                    Text(
                      '${page + 1} dari $totalPages',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      color: kAuthPrimary,
                      onPressed: page >= totalPages - 1
                          ? null
                          : () => setState(() => _page = page + 1),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
