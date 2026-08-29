import 'package:flutter/material.dart';
import 'package:form_up/core/utils/search_history.dart';

/// M3 SearchBar + SearchAnchor + history & auto-suggest per screen.
/// historyKey mis. "search_history_form" — beda tiap screen agar tidak campur.
class AppSearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted; // enter → langsung tanpa debounce
  final String hint;
  final bool filterActive;
  final VoidCallback? onOpenFilter;
  final String? historyKey;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hint,
    this.onSubmitted,
    this.filterActive = false,
    this.onOpenFilter,
    this.historyKey,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final SearchController _searchController;
  List<String> _history = [];
  bool _wasOpen = false;
  bool _didSubmit = false;

  @override
  void initState() {
    super.initState();
    _searchController = SearchController();
    _searchController.text = widget.controller.text;
    _searchController.addListener(() {
      // sync text
      if (widget.controller.text != _searchController.text) {
        widget.controller.text = _searchController.text;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchController.text.length),
        );
      }
      final isOpen = _searchController.isOpen;
      if (_wasOpen && !isOpen && !_didSubmit && _searchController.text.isNotEmpty) {
        _clearSearch(_searchController);
      }
      _wasOpen = isOpen;
      if (_didSubmit && !isOpen) _didSubmit = false;
      if (mounted) setState(() {});
    });
    widget.controller.addListener(_syncFromExternal);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (widget.historyKey == null) return;
    final h = await SearchHistory.get(widget.historyKey!);
    if (!mounted) return;
    setState(() => _history = h);
  }

  Future<void> _saveHistory(String q) async {
    if (widget.historyKey == null || q.trim().isEmpty) return;
    await SearchHistory.add(widget.historyKey!, q.trim());
    final h = await SearchHistory.get(widget.historyKey!);
    if (!mounted) return;
    setState(() => _history = h);
  }

  void _submit(String value) {
    _didSubmit = true;
    final q = value.trim();
    _saveHistory(q);
    if (widget.onSubmitted != null) {
      widget.onSubmitted!(q);
    } else {
      widget.onChanged(q);
    }
    // tutup view jika terbuka
    try {
      _searchController.closeView(q);
    } catch (_) {}
  }

  void _syncFromExternal() {
    if (_searchController.text != widget.controller.text) {
      _searchController.text = widget.controller.text;
      if (mounted) setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromExternal);
      widget.controller.addListener(_syncFromExternal);
      _searchController.text = widget.controller.text;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromExternal);
    _searchController.dispose();
    super.dispose();
  }

  List<Widget> _buildTrailing(SearchController controller) {
    final list = <Widget>[];
    if (controller.text.isNotEmpty) {
      list.add(
        IconButton(
          icon: const Icon(Icons.close, color: Colors.black54, size: 18),
          tooltip: 'Hapus',
          onPressed: () {
            // FIX: hanya clear field + reset list, jangan closeView/navigate
            controller.text = '';
            widget.controller.text = '';
            widget.controller.selection = const TextSelection.collapsed(offset: 0);
            widget.onChanged('');
            if (widget.onSubmitted != null) widget.onSubmitted!('');
            if (mounted) setState(() {});
          },
        ),
      );
    }
    if (widget.onOpenFilter != null) {
      list.add(
        Container(
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: widget.filterActive ? const Color(0xFFE2F3F2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            icon: Icon(Icons.tune, color: widget.filterActive ? const Color(0xFF2A9D8F) : Colors.black54, size: 20),
            tooltip: 'Filter & urutkan',
            onPressed: widget.onOpenFilter,
          ),
        ),
      );
    }
    return list;
  }

  void _clearSearch(SearchController controller) {
    controller.clear();
    widget.controller.clear();
    widget.onChanged('');
    if (widget.onSubmitted != null) widget.onSubmitted!('');
    try {
      controller.closeView('');
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _searchController,
      viewOnChanged: (value) {
        widget.onChanged(value);
        if (mounted) setState(() {});
      },
      viewOnSubmitted: (value) => _submit(value),
      viewLeading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black54),
        tooltip: 'Kembali',
        onPressed: () => _clearSearch(_searchController),
      ),
      viewTrailing: _buildTrailing(_searchController),
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          hintText: widget.hint,
          hintStyle: const WidgetStatePropertyAll<TextStyle>(
            TextStyle(color: Colors.black38, fontSize: 14),
          ),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            TextStyle(color: Colors.black87, fontSize: 14),
          ),
          backgroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
          elevation: const WidgetStatePropertyAll<double>(1),
          shadowColor: WidgetStatePropertyAll<Color>(Colors.black.withValues(alpha: 0.08)),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
          ),
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 16),
          ),
          leading: const Icon(Icons.search, color: Colors.black54, size: 20),
          trailing: _buildTrailing(controller),
          textInputAction: TextInputAction.search,
          onTap: () {
            controller.openView();
          },
          onChanged: (value) {
            widget.onChanged(value);
            setState(() {});
            if (!controller.isOpen) controller.openView();
          },
          onSubmitted: (value) => _submit(value),
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) {
        final query = controller.text.trim().toLowerCase();
        final hist = _history;
        final filteredHist = query.isEmpty
            ? hist
            : hist.where((h) => h.toLowerCase().contains(query)).toList();

        final items = <Widget>[];
        // Auto-suggest: jika ada query, tampilkan "Cari ..."
        if (query.isNotEmpty) {
          items.add(
            ListTile(
              leading: const Icon(Icons.search, color: Colors.black54, size: 20),
              title: Text('Cari "$query"', style: const TextStyle(fontSize: 14, color: Colors.black87)),
              onTap: () => _submit(query),
            ),
          );
        }
        // History per screen
        if (filteredHist.isNotEmpty) {
          if (query.isEmpty) {
            items.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Riwayat pencarian', style: TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.bold)),
                    InkWell(
                      onTap: () async {
                        if (widget.historyKey != null) {
                          await SearchHistory.clear(widget.historyKey!);
                          final h = await SearchHistory.get(widget.historyKey!);
                          if (mounted) setState(() => _history = h);
                        }
                      },
                      child: const Text('Hapus semua', style: TextStyle(color: Color(0xFF2A9D8F), fontSize: 12)),
                    ),
                  ],
                ),
              ),
            );
          }
          for (final h in filteredHist.take(5)) {
            items.add(
              ListTile(
                leading: const Icon(Icons.history, color: Colors.black38, size: 20),
                title: Text(h, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.black38),
                  onPressed: () async {
                    if (widget.historyKey != null) {
                      await SearchHistory.remove(widget.historyKey!, h);
                      final nh = await SearchHistory.get(widget.historyKey!);
                      if (mounted) setState(() => _history = nh);
                    }
                  },
                ),
                onTap: () {
                  controller.text = h;
                  widget.controller.text = h;
                  _submit(h);
                },
              ),
            );
          }
        } else if (query.isEmpty) {
          items.add(
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Ketik untuk mencari', style: TextStyle(color: Colors.black45, fontSize: 13)),
            ),
          );
        }
        return items;
      },
    );
  }
}
