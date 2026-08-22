import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

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
    return Row(
      children: [
        const Text(
          "Wajib dijawab",
          style: TextStyle(
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Switch(
          value: value,
          activeTrackColor: kAuthPrimary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
