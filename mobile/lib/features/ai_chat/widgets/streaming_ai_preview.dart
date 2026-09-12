import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/ai_chat/utils/action_json_parse.dart';
import 'package:form_up/features/ai_chat/widgets/ai_question_preview_card.dart';

/// Preview progresif saat AI streaming: pagar ```json disembunyikan,
/// tiap objek soal yang SUDAH lengkap langsung jadi kartu; objek yang
/// masih ditulis model tampil sebagai skeleton loading sepersekian detik.
/// Saat stream selesai, bubble diganti preview penuh (ActionJsonTabs).
class StreamingAiPreview extends StatefulWidget {
  final ValueNotifier<String> notifier;

  const StreamingAiPreview({super.key, required this.notifier});

  @override
  State<StreamingAiPreview> createState() => _StreamingAiPreviewState();
}

class _StreamingAiPreviewState extends State<StreamingAiPreview> {
  static const _throttleWindow = Duration(milliseconds: 400);

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
  void didUpdateWidget(covariant StreamingAiPreview oldWidget) {
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
    final text = _shown;
    if (text.trim().isEmpty) {
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

    final fenceAt = text.indexOf('```json');
    // Tanpa pagar JSON (obrolan biasa): teks polos seperti sebelumnya.
    if (fenceAt < 0) {
      return Text(
        text,
        style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5),
      );
    }

    final sq = extractStreamingQuestions(text);
    final intro = text.substring(0, fenceAt).trim();
    final total = sq.questions.length + (sq.hasOpenObject ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (intro.isNotEmpty) ...[
          Text(
            intro,
            style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5),
          ),
          const SizedBox(height: 8),
        ],
        // Header progres (bukan JSON mentah).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                total > 0 ? 'Menyusun $total soal…' : 'Menyiapkan soal…',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Kartu IDENTIK dengan preview final (LaTeX ikut ter-render).
        for (var i = 0; i < sq.questions.length; i++) ...[
          AiQuestionPreviewCard(
            question: sq.questions[i],
            index: i,
          ),
        ],
        if (sq.hasOpenObject)
          _StreamingSkeleton(index: sq.questions.length),
      ],
    );
  }
}

/// Skeleton untuk objek soal yang masih ditulis model.
class _StreamingSkeleton extends StatelessWidget {
  final int index;

  const _StreamingSkeleton({required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'Soal ${index + 1}…',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 10,
            width: 180,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    );
  }
}
