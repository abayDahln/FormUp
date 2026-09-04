import 'package:flutter/material.dart';

/// Controller dengan highlight background untuk teks @mention.
class MentionHighlightController extends TextEditingController {
  /// Token mention aktif (tanpa '@'), di-set dari state screen.
  List<String> mentionTokens = [];

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (mentionTokens.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final spans = <InlineSpan>[];
    var remaining = text;
    while (remaining.isNotEmpty) {
      int? best;
      String? bestTok;
      for (final t in mentionTokens) {
        final i = remaining.indexOf(t);
        if (i != -1 && (best == null || i < best)) {
          best = i;
          bestTok = t;
        }
      }
      if (best == null || bestTok == null) break;
      if (best > 0) spans.add(TextSpan(text: remaining.substring(0, best)));
      spans.add(
        TextSpan(
          text: remaining.substring(best, best + bestTok.length),
          style: (style ?? const TextStyle()).merge(
            const TextStyle(
              backgroundColor: Color(0x298FB5B3), // teal lembut ~16%
              color: Color(0xFF018081),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      remaining = remaining.substring(best + bestTok.length);
    }
    if (remaining.isNotEmpty) spans.add(TextSpan(text: remaining));
    return TextSpan(style: style, children: spans);
  }
}
