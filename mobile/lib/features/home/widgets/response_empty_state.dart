import 'package:flutter/material.dart';

/// Empty state berbentuk list untuk tab respons
class ResponseEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const ResponseEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.grey, size: 40),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
