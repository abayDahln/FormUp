import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

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
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            cursorColor: kAuthPrimary,
            decoration: InputDecoration(
              hintText: 'Cari form...',
              hintStyle: const TextStyle(color: kAuthText, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: kAuthText, size: 20),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                      onPressed: onClearSearch,
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
            color: filterActive ? kPrimarySoft : Colors.white,
            borderRadius: BorderRadius.circular(12),
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
