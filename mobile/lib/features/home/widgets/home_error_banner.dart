import 'package:flutter/material.dart';

/// Banner error pemuatan data beranda
class HomeErrorBanner extends StatelessWidget {
  final String message;

  const HomeErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE5E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC0392B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFC0392B), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFC0392B),
                fontSize: 13,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
