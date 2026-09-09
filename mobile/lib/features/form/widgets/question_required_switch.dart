import 'package:flutter/material.dart';

/// Baris switch "Wajib dijawab" pada section Pengaturan
class QuestionRequiredSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const QuestionRequiredSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          "Wajib dijawab",
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        Switch(
          value: value,
          activeTrackColor: cs.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
