import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Tombol tambah pertanyaan pada kelola soal
class AddQuestionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AddQuestionButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, color: Colors.white, size: 20),
      label: const Text(
        "Tambah Pertanyaan",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontFamily: kFontBold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: kAuthPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
