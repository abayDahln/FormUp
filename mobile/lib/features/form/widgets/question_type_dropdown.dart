import 'package:flutter/material.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/theme.dart';

/// Dropdown pemilihan tipe pertanyaan — M3 field (label floating di dalam outline)
class QuestionTypeDropdown extends StatelessWidget {
  final int typeId;
  final ValueChanged<int> onChanged;

  const QuestionTypeDropdown({
    super.key,
    required this.typeId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: typeId,
      decoration: formUpInputDecoration(
        labelText: 'Tipe Soal',
        prefixIcon: const Icon(Icons.category_outlined, size: 20),
      ),
      isExpanded: true,
      items: [
        for (final e in questionTypes.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(
              e.value.$1,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
    );
  }
}
