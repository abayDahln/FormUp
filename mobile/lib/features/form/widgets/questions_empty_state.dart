import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Tampilan kosong daftar soal pada kelola soal
class QuestionsEmptyState extends StatelessWidget {
  const QuestionsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xCCBDC9C8)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.quiz_outlined,
            color: Colors.grey,
            size: 40,
          ),
          const SizedBox(height: 10),
          const Text(
            'Belum ada pertanyaan.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
