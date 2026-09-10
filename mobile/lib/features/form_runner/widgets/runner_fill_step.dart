import 'package:flutter/material.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/utils/form_zoom.dart';
import 'package:form_up/core/theme.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/form_runner/controllers/runner_answer_store.dart';
import 'package:form_up/features/form_runner/widgets/runner_form_header_card.dart';
import 'package:form_up/features/form_runner/widgets/runner_question_card.dart';

/// Step pengisian: mode single-page atau multi-page beserta kartu soalnya.
class RunnerFillStep extends StatelessWidget {
  final PublicFormInfo info;
  final RunnerAnswerStore store;
  final List<PublicQuestion> questions;
  final bool isMultiPage;
  final int currentQuestion;
  final bool submitting;
  final Set<int> errorQuestionIds;
  final VoidCallback onSubmit;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final ValueChanged<int> onJumpTo;
  final ValueChanged<int> onAnswerChanged;
  final ValueChanged<int> onPickDateTime;
  final bool disablePaste;
  final ScrollPhysics? physics;
  // Tandai ragu-ragu ala web (khusus mode ujian).
  final Set<int> markedIds;
  final bool showMarkButton;
  final ValueChanged<int>? onToggleMark;

  const RunnerFillStep({
    super.key,
    required this.info,
    required this.store,
    required this.questions,
    required this.isMultiPage,
    required this.currentQuestion,
    required this.submitting,
    required this.errorQuestionIds,
    required this.onSubmit,
    required this.onNext,
    required this.onPrevious,
    required this.onJumpTo,
    required this.onAnswerChanged,
    required this.onPickDateTime,
    this.disablePaste = false,
    this.physics,
    this.markedIds = const {},
    this.showMarkButton = false,
    this.onToggleMark,
  });

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: submitting,
      child: isMultiPage ? _buildMultiPage() : _buildSinglePage(),
    );
  }

  /// Mode Single Page
  Widget _buildSinglePage() {
    return SingleChildScrollView(
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RunnerFormHeaderCard(info: info, questionCount: questions.length),
          const SizedBox(height: 16),
          for (var i = 0; i < questions.length; i++) ...[
            _buildQuestionCard(i),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          AuthPrimaryButton(
            label: submitting ? "Mengirim..." : "Kirim Jawaban",
            loading: submitting,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Mode Multi Page - quiz: inline nav <- 1/10 -> , tanpa footer, tap label untuk jump
  Widget _buildMultiPage() {
    final isLast = currentQuestion == questions.length - 1;
    final canGoBack = currentQuestion > 0;
    return ListView(
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        _buildQuestionCard(currentQuestion),
        const SizedBox(height: 16),
        _InlineQuizNav(
          current: currentQuestion,
          total: questions.length,
          canGoBack: canGoBack,
          isLast: isLast,
          submitting: submitting,
          store: store,
          questions: questions,
          markedIds: markedIds,
          onPrevious: onPrevious,
          onNext: onNext,
          onSubmit: onSubmit,
          onJump: onJumpTo,
        ),
      ],
    );
  }

  Widget _buildQuestionCard(int index) {
    final q = questions[index];
    return ValueListenableBuilder<double>(
      valueListenable: formZoom,
      builder: (context, zoom, _) => RunnerQuestionCard(
        zoom: zoom,
      cardKey: store.questionKeys[index],
      index: index,
      question: q,
      hasError: errorQuestionIds.contains(q.id),
      disablePaste: disablePaste,
      isMarked: markedIds.contains(q.id),
      showMarkButton: showMarkButton,
      onToggleMark: onToggleMark == null ? null : () => onToggleMark!(q.id),
      essayController: store.textAnswers[q.id],
      essayFocusNode: store.essayFocusNodes[q.id],
      singleValue: store.singleAnswers[q.id],
      multiValue: store.multiAnswers[q.id] ?? {},
      tfValue: store.tfAnswers[q.id],
      datetimeValue: store.datetimeAnswers[q.id],
      onEssayChanged: (_) => onAnswerChanged(q.id),
      onSingleChanged: (v) {
        store.singleAnswers[q.id] = v;
        onAnswerChanged(q.id);
      },
      onMultiChanged: (v) {
        store.multiAnswers[q.id] = v;
        onAnswerChanged(q.id);
      },
      onTfChanged: (v) {
        store.tfAnswers[q.id] = v;
        onAnswerChanged(q.id);
      },
      onPickDateTime: () => onPickDateTime(q.id),
      ),
    );
  }
}

/// Inline nav simple <- 1/10 -> , previous hilang di soal 1
class _InlineQuizNav extends StatelessWidget {
  final int current;
  final int total;
  final bool canGoBack;
  final bool isLast;
  final bool submitting;
  final RunnerAnswerStore store;
  final List<PublicQuestion> questions;
  final Set<int> markedIds;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSubmit;
  final ValueChanged<int> onJump;

  const _InlineQuizNav({
    required this.current,
    required this.total,
    required this.canGoBack,
    required this.isLast,
    required this.submitting,
    required this.store,
    required this.questions,
    this.markedIds = const {},
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
    required this.onJump,
  });

  // Kuning ragu-ragu ala web (di atas hijau terjawab, di bawah soal aktif).
  static const _markYellow = Color(0xFFFACC15);

  void _showJumpPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              const Text('Daftar soal', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _legend(ctx, Theme.of(ctx).colorScheme.primaryContainer, 'Terjawab'),
                  _legend(ctx, Theme.of(ctx).colorScheme.surfaceContainerHighest, 'Belum'),
                  _legend(ctx, _markYellow, 'Ragu-ragu'),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                itemCount: total,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.2),
                itemBuilder: (c, i) {
                  final selected = i == current;
                  final answered = store.isAnswered(questions[i]);
                  final marked = markedIds.contains(questions[i].id);
                  final cellColor = selected
                      ? Theme.of(ctx).colorScheme.primary
                      : marked
                          ? _markYellow
                          : answered
                              ? Theme.of(ctx).colorScheme.primaryContainer
                              : Theme.of(ctx).colorScheme.surfaceContainerHighest;
                  final numColor = selected || marked
                      ? Colors.white
                      : answered
                          ? Theme.of(ctx).colorScheme.primary
                          : Theme.of(ctx).colorScheme.onSurface;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      onJump(i);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cellColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: selected ? Theme.of(ctx).colorScheme.primary : marked ? _markYellow : (answered ? Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.5) : Theme.of(ctx).colorScheme.outlineVariant)),
                          ),
                          child: Text('${i + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: numColor)),
                        ),
                        if ((answered || marked) && !selected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: marked ? _markYellow : Theme.of(ctx).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _legend(BuildContext ctx, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (canGoBack)
          IconButton(
            tooltip: 'Sebelumnya',
            onPressed: onPrevious,
            icon:  Icon(Icons.arrow_back, size: 20, color: cs.onSurface),
            style: IconButton.styleFrom(backgroundColor: cs.surface, side:  BorderSide(color: cs.outlineVariant)),
          )
        else
          const SizedBox(width: 48),
        Card(
          margin: EdgeInsets.zero,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          surfaceTintColor: Colors.transparent,
          color: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusMd),
            side:  BorderSide(color: cs.surfaceContainerHighest),
          ),
          child: InkWell(
            onTap: () => _showJumpPicker(context),
            borderRadius: BorderRadius.circular(kRadiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text('${current + 1}/$total', style:  TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: kFontBold, color: cs.onSurface)),
            ),
          ),
        ),
        if (isLast)
          FilledButton(
            onPressed: submitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: submitting
                ?    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.surface))
                : const Text('Kirim', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold)),
          )
        else
          IconButton(
            tooltip: 'Berikutnya',
            onPressed: onNext,
            icon: Icon(Icons.arrow_forward, size: 20, color: cs.onPrimary),
            style: IconButton.styleFrom(backgroundColor: cs.primary),
          ),
      ],
    );
  }
}
