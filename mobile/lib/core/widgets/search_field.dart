import 'package:flutter/material.dart';
import 'package:form_up/core/utils/search_history.dart';

/// Field pencarian inline: ketik langsung di field (tanpa pindah ke
/// fullscreen search view) + dropdown riwayat per screen.
/// API sama seperti sebelumnya sehingga semua pemanggil tidak berubah:
/// [controller] (two-way sync), [onChanged] (filter live),
/// [onSubmitted] (enter → simpan riwayat), [historyKey] (riwayat per screen).
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
  List<String> _history = [];
  // Controller internal milik Autocomplete (dipegang untuk sync eksternal).
  TextEditingController? _inner;
  // True sesaat setelah tombol X: jangan tampilkan dropdown sampai user mengetik lagi.
  bool _suppressOptions = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFromExternal);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (widget.historyKey == null) return;
    try {
      final h = await SearchHistory.get(widget.historyKey!);
      if (!mounted) return;
      setState(() => _history = h);
      _refreshOptions();
    } catch (_) {
      // Riwayat pencarian bersifat opsional — gagal baca diabaikan.
    }
  }

  Future<void> _saveHistory(String q) async {
    if (widget.historyKey == null || q.trim().isEmpty) return;
    await SearchHistory.add(widget.historyKey!, q.trim());
    final h = await SearchHistory.get(widget.historyKey!);
    if (!mounted) return;
    setState(() => _history = h);
    _refreshOptions();
  }

  /// Paksa Autocomplete membangun ulang daftar opsi (mis. setelah
  /// riwayat dimuat/diubah tanpa perubahan teks).
  void _refreshOptions() {
    final inner = _inner;
    if (inner == null || !mounted) return;
    inner.value = inner.value.copyWith();
  }

  void _submit(String value) {
    final q = value.trim();
    _saveHistory(q);
    if (widget.onSubmitted != null) {
      widget.onSubmitted!(q);
    } else {
      widget.onChanged(q);
    }
  }

  void _syncFromExternal() {
    final inner = _inner;
    if (inner != null && inner.text != widget.controller.text) {
      inner.text = widget.controller.text;
      inner.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.controller.text.length),
      );
      if (mounted) setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromExternal);
      widget.controller.addListener(_syncFromExternal);
      final inner = _inner;
      if (inner != null) inner.text = widget.controller.text;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromExternal);
    super.dispose();
  }

  void _clear() {
    _suppressOptions = true;
    _inner?.clear();
    widget.controller.clear();
    widget.onChanged('');
    if (widget.onSubmitted != null) widget.onSubmitted!('');
    if (mounted) setState(() {});
  }

  Iterable<String> _optionsFor(TextEditingValue value) {
    if (_suppressOptions || _history.isEmpty) return const Iterable.empty();
    final query = value.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _history
        : _history.where((h) => h.toLowerCase().contains(query)).toList();
    return filtered.take(5);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Autocomplete<String>(
      displayStringForOption: (o) => o,
      optionsBuilder: _optionsFor,
      optionsMaxHeight: 300,
      onSelected: (option) {
        _suppressOptions = true;
        _inner?.text = option;
        widget.controller.text = option;
        _submit(option);
        if (mounted) setState(() {});
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        _inner = textEditingController;
        if (textEditingController.text != widget.controller.text) {
          textEditingController.text = widget.controller.text;
        }
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 14),
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            _suppressOptions = false;
            if (widget.controller.text != value) {
              widget.controller.text = value;
              widget.controller.selection = TextSelection.fromPosition(
                TextPosition(offset: value.length),
              );
            }
            widget.onChanged(value);
            setState(() {});
          },
          onSubmitted: _submit,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            prefixIcon:
                Icon(Icons.search, color: cs.onSurfaceVariant, size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (textEditingController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.close,
                        color: cs.onSurfaceVariant, size: 18),
                    tooltip: 'Hapus',
                    onPressed: _clear,
                  ),
                if (widget.onOpenFilter != null)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: widget.filterActive
                          ? cs.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.tune,
                          color: widget.filterActive
                              ? cs.primary
                              : cs.onSurfaceVariant,
                          size: 20),
                      tooltip: 'Filter & urutkan',
                      onPressed: widget.onOpenFilter,
                    ),
                  ),
              ],
            ),
            filled: true,
            fillColor: cs.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final cs = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Riwayat pencarian',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            if (widget.historyKey != null) {
                              await SearchHistory.clear(widget.historyKey!);
                              final h = await SearchHistory.get(
                                  widget.historyKey!);
                              if (mounted) {
                                setState(() => _history = h);
                                _refreshOptions();
                              }
                            }
                          },
                          child: Text(
                            'Hapus semua',
                            style: TextStyle(
                                color: cs.primary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final h in options)
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.history,
                          color: cs.onSurfaceVariant, size: 20),
                      title: Text(h,
                          style: TextStyle(
                              fontSize: 14, color: cs.onSurface)),
                      trailing: IconButton(
                        icon: Icon(Icons.close,
                            size: 16, color: cs.onSurfaceVariant),
                        tooltip: 'Hapus riwayat ini',
                        onPressed: () async {
                          if (widget.historyKey != null) {
                            await SearchHistory.remove(
                                widget.historyKey!, h);
                            final nh = await SearchHistory.get(
                                widget.historyKey!);
                            if (mounted) {
                              setState(() => _history = nh);
                              _refreshOptions();
                            }
                          }
                        },
                      ),
                      onTap: () => onSelected(h),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
