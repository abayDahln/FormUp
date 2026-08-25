import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Field pencarian untuk komponen di luar card: stroke lembut #BDC9C8
/// (input di dalam card memakai stroke tegas #6E7979), fokus kPrimary.
class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      cursorColor: kAuthPrimary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        prefixIcon:
            const Icon(Icons.search, color: Colors.black54, size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black54, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7.5),
          borderSide: const BorderSide(color: Color(0xFFBDC9C8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7.5),
          borderSide: const BorderSide(color: kAuthPrimary, width: 1.5),
        ),
      ),
    );
  }
}
