import 'package:flutter/material.dart';

/// Tampilan kosong daftar soal pada kelola soal
class QuestionsEmptyState extends StatelessWidget {
  const QuestionsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.quiz_outlined, color: Colors.black38, size: 40),
            const SizedBox(height: 10),
            const Text(
              'Belum ada pertanyaan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
