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
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
    required this.onJump,
  });

  void _showJumpPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              const Text('Daftar soal', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                itemCount: total,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.2),
                itemBuilder: (c, i) {
                  final selected = i == current;
                  final answered = store.isAnswered(questions[i]);
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
                            color: selected ? kAuthPrimary : (answered ? const Color(0xFFE0F2F1) : const Color(0xFFF0F4F4)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: selected ? kAuthPrimary : (answered ? kAuthPrimary.withValues(alpha: 0.5) : const Color(0xFFBDC9C8))),
                          ),
                          child: Text('${i + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: selected ? Colors.white : (answered ? kAuthPrimary : Colors.black87))),
                        ),
                        if (answered)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: selected ? Colors.white : kAuthPrimary,
                                shape: BoxShape.circle,
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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (canGoBack)
          IconButton(
            tooltip: 'Sebelumnya',
            onPressed: onPrevious,
            icon: const Icon(Icons.arrow_back, size: 20, color: Colors.black87),
            style: IconButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: Color(0xFFBDC9C8))),
          )
        else
          const SizedBox(width: 48),
        Card(
          margin: EdgeInsets.zero,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          surfaceTintColor: Colors.transparent,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusMd),
            side: const BorderSide(color: Color(0xFFE5E8E8)),
          ),
          child: InkWell(
            onTap: () => _showJumpPicker(context),
            borderRadius: BorderRadius.circular(kRadiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text('${current + 1}/$total', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: kFontBold, color: Colors.black87)),
            ),
          ),
        ),
        if (isLast)
          FilledButton(
            onPressed: submitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: kAuthPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: submitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Kirim', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold)),
          )
        else
          IconButton(
            tooltip: 'Berikutnya',
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward, size: 20, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: kAuthPrimary),
          ),
      ],
    );
  }
}
