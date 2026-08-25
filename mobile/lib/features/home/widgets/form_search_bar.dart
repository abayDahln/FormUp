import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/search_field.dart';

/// Bar pencarian + tombol filter pada tab Form Saya
class FormSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearSearch;
  final bool filterActive;
  final VoidCallback onOpenFilter;

  const FormSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClearSearch,
    required this.filterActive,
    required this.onOpenFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppSearchField(
            controller: controller,
            onChanged: onChanged,
            hint: 'Cari form...',
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: filterActive ? kPrimarySoft : Colors.white,
            borderRadius: BorderRadius.circular(7.5),
            border: Border.all(color: const Color(0xFFBDC9C8)),
          ),
          child: IconButton(
            icon: const Icon(Icons.tune, color: kAuthPrimary, size: 22),
            tooltip: 'Filter & urutkan',
            onPressed: onOpenFilter,
          ),
        ),
      ],
    );
  }
}
