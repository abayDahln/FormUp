import 'package:flutter/material.dart';

/// Ikon chat dengan bintang khas AI (chat bubble + sparkle star)
/// Dipakai konsisten di navigation bar, banner, app bar AI Chat.
class AiChatIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool filled;

  const AiChatIcon({super.key, this.size = 24, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    // Base chat bubble, bintang kecil di pojok kanan atas
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          filled ? Icons.chat_bubble : Icons.chat_bubble_outline,
          size: size,
          color: color,
        ),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: filled ? color : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              size: size * 0.52,
              color: filled ? Colors.white : color,
            ),
          ),
        ),
      ],
    );
  }
}
