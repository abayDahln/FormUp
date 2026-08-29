import 'package:flutter/material.dart';

/// Tampilan kosong daftar form (dengan / tanpa filter aktif)
class FormEmptyState extends StatelessWidget {
  final bool hasFilter;

  const FormEmptyState({super.key, required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilter ? Icons.search_off : Icons.description_outlined,
              color: Colors.black38,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              hasFilter ? 'Tidak ada form yang cocok.' : 'Belum ada form. Buat form pertama Anda!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
