import 'package:flutter/material.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/form_runner/controllers/runner_answer_store.dart';
import 'package:form_up/features/form_runner/widgets/runner_form_header_card.dart';
import 'package:form_up/features/form_runner/widgets/runner_multi_page_nav_bar.dart';
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

  /// Mode Multi Page
  Widget _buildMultiPage() {
    final isLast = currentQuestion == questions.length - 1;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Soal ${currentQuestion + 1} dari ${questions.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                '${((currentQuestion + 1) / questions.length * 100).round()}%',
                style: const TextStyle(fontSize: 12, color: kAuthPrimary),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            children: [
              if (currentQuestion == 0) ...[
                RunnerFormHeaderCard(
                  info: info,
                  questionCount: questions.length,
                ),
                const SizedBox(height: 16),
              ],
              _buildQuestionCard(currentQuestion),
            ],
          ),
        ),
        RunnerMultiPageNavBar(
          canGoBack: currentQuestion > 0,
          isLast: isLast,
          submitting: submitting,
          onBack: onPrevious,
          onNextOrSubmit: isLast ? onSubmit : onNext,
        ),
      ],
    );
  }

  Widget _buildQuestionCard(int index) {
    final q = questions[index];
    return RunnerQuestionCard(
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
    );
  }
}
