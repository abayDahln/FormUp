import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/search_field.dart';

/// Bar pencarian + tombol filter pada tab Form Saya
class FormSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearSearch;
  final bool filterActive;
  final VoidCallback onOpenFilter;
  final String? historyKey;
  final ValueChanged<String>? onSubmitted;

  const FormSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClearSearch,
    required this.filterActive,
    required this.onOpenFilter,
    this.historyKey,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return AppSearchField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted ?? onChanged,
      hint: 'Cari form...',
      historyKey: historyKey ?? 'search_history_form',
      filterActive: filterActive,
      onOpenFilter: onOpenFilter,
    );
  }
}
