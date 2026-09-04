import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Teks AI yang sedang di-stream: rebuild terisolasi via notifier —
/// sisa ListView tidak ikut rebuild per chunk.
class StreamingAiText extends StatelessWidget {
  /// Notifier live dari bubble yang sedang di-stream.
  /// ValueListenableBuilder memastikan HANYA widget ini yang rebuild
  /// setiap chunk tiba — ListView & bubble lain tidak tersentuh,
  /// sehingga tidak ada frame drop / text jumping dari rebuild massal.
  final ValueNotifier<String> notifier;

  const StreamingAiText({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: notifier,
      builder: (ctx, text, _) {
        if (text.isEmpty) {
          return const Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'AI mengetik...',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          );
        }
        return GptMarkdown(
          text,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        );
      },
    );
  }
}
