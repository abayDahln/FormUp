import 'dart:async';

import 'package:flutter/material.dart';

/// Teks AI yang sedang di-stream: rebuild terisolasi + ter-throttle.
///
/// - Selama streaming: tampilkan TEKS POLOS (bukan markdown) yang
///   diperbarui maksimal tiap 300ms. Fence ``` / rumus `$$..$$` yang
///   setengah jadi tidak di-parse → tanpa flicker, tanpa parse error,
///   tanpa layout jumping per chunk.
/// - Setelah selesai (`onDone` → `disposeStream`), bubble beralih ke
///   render markdown/LaTeX penuh via `ChatBubble._buildAiBody`.
/// - Hanya widget ini yang rebuild (listener notifier), ListView &
///   bubble lain tidak tersentuh.
class StreamingAiText extends StatefulWidget {
  /// Notifier live dari bubble yang sedang di-stream.
  final ValueNotifier<String> notifier;

  const StreamingAiText({super.key, required this.notifier});

  @override
  State<StreamingAiText> createState() => _StreamingAiTextState();
}

class _StreamingAiTextState extends State<StreamingAiText> {
  static const _throttleWindow = Duration(milliseconds: 300);

  String _shown = '';
  Timer? _throttle;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _shown = widget.notifier.value;
    widget.notifier.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant StreamingAiText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.notifier, widget.notifier)) {
      oldWidget.notifier.removeListener(_onTick);
      widget.notifier.addListener(_onTick);
      _shown = widget.notifier.value;
    }
  }

  void _onTick() {
    if (!mounted) return;
    if (_throttle?.isActive ?? false) {
      _pending = true;
      return;
    }
    setState(() => _shown = widget.notifier.value);
    _throttle = Timer(_throttleWindow, () {
      if (!mounted) return;
      if (_pending) {
        _pending = false;
        setState(() => _shown = widget.notifier.value);
      }
    });
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onTick);
    _throttle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_shown.isEmpty) {
      return Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'AI mengetik...',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      );
    }
    return Text(
      _shown,
      style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5),
    );
  }
}
