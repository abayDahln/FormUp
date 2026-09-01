import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/loading_indicator.dart';
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/search_field.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/router/app_router.dart';

class FormFeedbacksScreen extends StatefulWidget {
  final int formId;
  final String formTitle;

  const FormFeedbacksScreen({
    super.key,
    required this.formId,
    required this.formTitle,
  });

  @override
  State<FormFeedbacksScreen> createState() => _FormFeedbacksScreenState();
}

enum _FeedbackSort { newest, oldest }
enum _FeedbackCategory { all, general, inappropriate, misleading, bug }

extension _FeedbackCategoryExt on _FeedbackCategory {
  String get label => switch (this) {
        _FeedbackCategory.all => 'Semua',
        _FeedbackCategory.general => 'General',
        _FeedbackCategory.inappropriate => 'Inappropriate',
        _FeedbackCategory.misleading => 'Misleading',
        _FeedbackCategory.bug => 'Bug',
      };
  String? get reasonValue => switch (this) {
        _FeedbackCategory.all => null,
        _FeedbackCategory.general => 'General Feedback',
        _FeedbackCategory.inappropriate => 'Inappropriate Content',
        _FeedbackCategory.misleading => 'Misleading Information',
        _FeedbackCategory.bug => 'Bug / Technical Issue',
      };
}

class _FormFeedbacksScreenState extends State<FormFeedbacksScreen> {
  List<FormFeedbackItem> _feedbacks = [];
  bool _loading = true;
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  _FeedbackSort _sort = _FeedbackSort.newest;
  _FeedbackCategory _category = _FeedbackCategory.all;

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

  void _onSearchImmediate(String v) {
    _debounce?.cancel();
    setState(() => _query = v.trim().toLowerCase());
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = v.trim().toLowerCase());
    });
  }

  List<FormFeedbackItem> get _filtered {
    var list = _feedbacks.where((fb) {
      if (_category != _FeedbackCategory.all) {
        final rv = _category.reasonValue!;
        if (fb.reason.trim().toLowerCase() != rv.toLowerCase()) return false;
      }
      if (_query.isEmpty) return true;
      final q = _query;
      final name = fb.userName.toLowerCase();
      final reason = fb.reason.toLowerCase();
      final desc = (fb.description ?? '').toLowerCase();
      return name.contains(q) || reason.contains(q) || desc.contains(q);
    }).toList();
    list.sort((a, b) => _sort == _FeedbackSort.newest ? b.createdAt.compareTo(a.createdAt) : a.createdAt.compareTo(b.createdAt));
    return list;
  }

  bool _filterOpen = false;

  Future<void> _openFilterSheet() async {
    if (_filterOpen) return;
    _filterOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Filter Umpan Balik', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: kFontBold, color: Colors.black87)),
              const SizedBox(height: 12),
              const Text('Kategori', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _FeedbackCategory.values)
                    ChoiceChip(
                      label: Text(c.label),
                      selected: _category == c,
                      selectedColor: kAuthPrimary.withValues(alpha: 0.15),
                      labelStyle: TextStyle(fontSize: 12, fontWeight: _category == c ? FontWeight.bold : FontWeight.normal, fontFamily: _category == c ? kFontBold : null, color: _category == c ? kAuthPrimary : Colors.black87),
                      onSelected: (_) {
                        setState(() => _category = c);
                        Navigator.pop(sheetContext);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Urutkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Terbaru'),
                    selected: _sort == _FeedbackSort.newest,
                    selectedColor: kAuthPrimary.withValues(alpha: 0.15),
                    onSelected: (_) {
                      setState(() => _sort = _FeedbackSort.newest);
                      Navigator.pop(sheetContext);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Terlama'),
                    selected: _sort == _FeedbackSort.oldest,
                    selectedColor: kAuthPrimary.withValues(alpha: 0.15),
                    onSelected: (_) {
                      setState(() => _sort = _FeedbackSort.oldest);
                      Navigator.pop(sheetContext);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _category = _FeedbackCategory.all;
                      _sort = _FeedbackSort.newest;
                    });
                    Navigator.pop(sheetContext);
                  },
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: const Text('Reset Filter'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => _filterOpen = false);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await FormService.getFormFeedbacks(widget.formId);
      if (!mounted) return;
      setState(() {
        _feedbacks = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xCCBDC9C8))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title: Text(
          'Umpan Balik Form',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: _loading
          ? const LoadingOverlay(contained: true)
          : AuthBackground(
              plain: true,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: AppSearchField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: _onSearchImmediate,
                        hint: 'Cari nama atau isi umpan balik...',
                        historyKey: 'search_history_feedback_form_${widget.formId}',
                        filterActive: _category != _FeedbackCategory.all || _sort != _FeedbackSort.newest,
                        onOpenFilter: _openFilterSheet,
                      ),
                    ),
                    Expanded(
                      child: _feedbacks.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.feedback_outlined, color: Colors.black38, size: 40),
                                    SizedBox(height: 12),
                                    Text(
                                      'Belum ada umpan balik untuk form ini.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 14, color: Colors.black45),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _filtered.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.search_off, color: Colors.black38, size: 36),
                                        const SizedBox(height: 10),
                                        Text(
                                          _query.isEmpty && _category == _FeedbackCategory.all
                                              ? 'Tidak ada hasil'
                                              : 'Tidak ada hasil untuk "${_searchController.text}"${_category != _FeedbackCategory.all ? ' • ${ _category.label}' : ''}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 13, color: Colors.black45),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : AppRefreshIndicator(
                                  onRefresh: _load,
                                  indicatorColor: kAuthPrimary,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                    itemCount: _filtered.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final fb = _filtered[index];
                                      final localDate = fb.createdAt.toLocal();
                                      final timeStr = "${localDate.day}/${localDate.month}/${localDate.year} "
                                          "${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}";

                                      return Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFBDC9C8).withOpacity(0.5)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    fb.userName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontFamily: kFontBold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  timeStr,
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(color: kAuthPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                              child: Text(
                                                fb.reason,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: kFontBold, color: kAuthPrimary),
                                              ),
                                            ),
                                            if (fb.description != null && fb.description!.trim().isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                fb.description!,
                                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}