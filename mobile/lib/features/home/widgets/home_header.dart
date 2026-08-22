import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Sapaan pengguna di beranda
class HomeHeader extends StatelessWidget {
  final String username;

  const HomeHeader({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Halo, ${username.isNotEmpty ? username : 'Pengguna'}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          "Apa yang ingin Anda lakukan hari ini?",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }
}
