import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Tombol tambah pertanyaan pada kelola soal
class AddQuestionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AddQuestionButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, color: kAuthPrimary),
      label: const Text(
        "Tambah Pertanyaan",
        style: TextStyle(color: kAuthPrimary),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: kAuthPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
