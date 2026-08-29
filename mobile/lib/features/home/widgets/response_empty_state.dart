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
    // Dipakai di dalam Expanded/TabBarView — center vertikal & horizontal.
    // Untuk pull-to-refresh, parent sudah menyediakan scroll; di sini cukup Center.
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black38, size: 40),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
