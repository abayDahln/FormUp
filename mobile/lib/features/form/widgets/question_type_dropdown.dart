import 'package:flutter/material.dart';
import 'package:form_up/core/models/question_draft.dart';

/// Dropdown pemilihan tipe pertanyaan pada layar edit soal
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
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: typeId,
        isExpanded: true,
        items: [
          for (final e in questionTypes.entries)
            DropdownMenuItem(
              value: e.key,
              child: Text(
                e.value.$1,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ),
        ],
        onChanged: (v) {
          if (v == null) return;
          onChanged(v);
        },
      ),
    );
  }
}
