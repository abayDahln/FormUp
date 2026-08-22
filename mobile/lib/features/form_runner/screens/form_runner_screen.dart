import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form_runner/controllers/form_runner_controller.dart';
import 'package:form_up/features/form_runner/widgets/feedback_sheet.dart';
import 'package:form_up/features/form_runner/widgets/runner_code_step.dart';
import 'package:form_up/features/form_runner/widgets/runner_exit_dialog.dart';
import 'package:form_up/features/form_runner/widgets/runner_fill_step.dart';
import 'package:form_up/features/form_runner/widgets/runner_result_view.dart';
import 'package:form_up/features/form_runner/widgets/runner_screen_shell.dart';
import 'package:form_up/features/form_runner/widgets/runner_submitted_dialog.dart';

/// Alur: kode → token → jawaban → hasil
class FormRunnerView extends StatefulWidget {
  final String? initialCode;
  final String? initialToken;
  final bool showTitle;
  final ValueChanged<PublicFormInfo>? onInfoLoaded;

  const FormRunnerView({
    super.key,
    this.initialCode,
    this.initialToken,
    this.showTitle = true,
    this.onInfoLoaded,
  });

  @override
  State<FormRunnerView> createState() => FormRunnerViewState();
}

/// Halaman mengerjakan form
class FormRunnerScreen extends StatefulWidget {
  final String? initialCode;
  final String? initialToken;

  const FormRunnerScreen({super.key, this.initialCode, this.initialToken});

  @override
  State<FormRunnerScreen> createState() => _FormRunnerScreenState();
}

enum _RunnerStep { code, fill, result }

class _FormRunnerScreenState extends State<FormRunnerScreen> {
  final GlobalKey<FormRunnerViewState> _viewKey =
      GlobalKey<FormRunnerViewState>();
  int? _timerSeconds;

  void _onInfoLoaded(PublicFormInfo info) {
    if (mounted) setState(() => _timerSeconds = info.timerDuration);
  }

  void _onTimerExpired() {
    _viewKey.currentState?.handleTimerExpired();
  }

  @override
  Widget build(BuildContext context) {
    return RunnerScreenShell(
      timerSeconds: _timerSeconds,
      onTimerExpired: _onTimerExpired,
      child: FormRunnerView(
        key: _viewKey,
        initialCode: widget.initialCode,
        initialToken: widget.initialToken,
        onInfoLoaded: _onInfoLoaded,
      ),
    );
  }
}

class FormRunnerViewState extends State<FormRunnerView> {
  AppRouterDelegate? _router;
  final FormRunnerController _c = FormRunnerController();

  _RunnerStep _step = _RunnerStep.code;
  bool _loading = false;
  bool _submitting = false;

  // ID soal wajib yang belum dijawab (untuk indikator merah saat submit gagal).
  final Set<int> _errorQuestionIds = {};

  bool get _isLoggedIn => _c.isLoggedIn;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      _c.tokenController.text = widget.initialToken!;
    }
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _c.codeController.text = widget.initialCode!;
      _submitCode();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= AppRouter.of(context);
    _router!.pushBackGuard(_confirmExit);
  }

  @override
  void dispose() {
    _router?.popBackGuard();
    _c.dispose();
    super.dispose();
  }

  /// Konfirmasi keluar dari form.
  /// Mengembalikan true bila boleh keluar (sudah kirim & keluar), false bila batal.
  Future<bool> _confirmExit() async {
    // Hanya intercept saat sedang mengerjakan (fill step)
    if (_step != _RunnerStep.fill) return true;
    if (!mounted) return true;
    return showRunnerExitDialog(context, _submit);
  }

  /// Panggil saat timer form habis (dari countdown di AppBar).
  Future<void> handleTimerExpired() async {
    await _autoSubmit();
  }

  Future<void> _submitCode() async {
    if (_loading) return;
    final code = _c.codeController.text.trim();
    if (code.isEmpty) {
      showAuthToast(context, "Masukkan kode form terlebih dahulu", isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final info = await _c.fetchInfo(code);
      if (!mounted) return;
      // Pemilik tidak boleh mengisi form sendiri.
      if (info == null) {
        showAuthToast(
          context,
          "Anda tidak dapat mengisi form yang Anda buat sendiri",
          isError: true,
        );
        return;
      }
      widget.onInfoLoaded?.call(info);
      if (_c.requiresToken) {
        // Token sudah diberikan dari screen sebelumnya → langsung isi form
        if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
          await _loadQuestions();
        } else {
          setState(() => _step = _RunnerStep.code);
        }
      } else {
        await _loadQuestions();
      }
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    try {
      await _c.fetchQuestions(_c.tokenController.text);
      if (!mounted) return;
      setState(() => _step = _RunnerStep.fill);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Auto submit saat waktu habis: field kosong dibiarkan kosong (tidak dianggap
  /// error), lalu tampilkan dialog konfirmasi bahwa jawaban sudah terkirim.
  Future<void> _autoSubmit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final answers = _c.store.collectAutoAnswers(_c.questions);
      final responseId = await _c.submitAnswers(answers);
      if (!mounted) return;

      // Hasil hanya untuk user login
      if (_isLoggedIn) {
        final result = await _c.fetchResult(responseId);
        if (!mounted) return;
        setState(() {
          _c.result = result;
          _step = _RunnerStep.result;
          _errorQuestionIds.clear();
        });
      }

      // Konfirmasi jawaban sudah terkirim (Kembali / Lihat Respons)
      await _handleSubmittedAction(
        message: 'Waktu pengerjaan telah habis, jawaban Anda sudah terkirim.',
      );
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Tampilkan dialog konfirmasi terkirim lalu proses aksinya.
  Future<void> _handleSubmittedAction({String message = 'Jawaban Anda sudah terkirim.'}) async {
    final action = await showRunnerSubmittedDialog(
      context,
      message: message,
      viewResponse: _isLoggedIn,
    );
    if (!mounted) return;
    if (action == 'back') {
      if (_isLoggedIn) {
        final router = AppRouter.of(context);
        router.goHome(router.username);
      } else {
        AppRouter.of(context).pop();
      }
    }
    // action 'result' atau dismiss → tetap di halaman hasil (sudah di-set di atas).
  }

  /// Scroll ke soal belum dijawab pertama dan fokus ke field esai-nya (jika ada).
  void _scrollToUnanswered(int index) {
    if (_c.formTypeId == 2 && _c.questions.length > 1) {
      // Mode multi-page: pindah ke halaman soal tsb.
      setState(() => _c.currentQuestion = index);
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusEssayIfAny(index));
      return;
    }
    // Mode single-page: scroll ke kartu soal tsb lalu fokus.
    final ctx = _c.store.questionKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusEssayIfAny(index));
  }

  void _focusEssayIfAny(int index) {
    final q = _c.questions[index];
    if (q.typeId == 1) {
      _c.store.essayFocusNodes[q.id]?.requestFocus();
    }
  }

  /// Submit jawaban. Mengembalikan true bila berhasil, false bila gagal/validasi.
  Future<bool> _submit() async {
    if (_submitting) return false;
    final firstUnanswered = _c.store.firstUnansweredIndex(_c.questions);
    if (firstUnanswered != null) {
      setState(() {
        _errorQuestionIds
          ..clear()
          ..addAll(_c.store.unansweredIds(_c.questions));
      });
      _scrollToUnanswered(firstUnanswered);
      showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
      return false;
    }
    final answers = _c.store.collectValidatedAnswers(_c.questions);
    if (answers == null) {
      showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
      return false;
    }

    setState(() => _submitting = true);
    try {
      final responseId = await _c.submitAnswers(answers);

      if (!mounted) return false;

      // Hasil hanya untuk user login
      if (!_isLoggedIn) {
        showAuthToast(context, "Jawaban berhasil dikirim");
        await _reset();
        return true;
      }

      final result = await _c.fetchResult(responseId);
      if (!mounted) return false;
      setState(() {
        _c.result = result;
        _step = _RunnerStep.result;
        _errorQuestionIds.clear();
      });
      await _handleSubmittedAction();
      return true;
    } catch (e) {
      if (!mounted) return false;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _step = _RunnerStep.code;
      _errorQuestionIds.clear();
      _c.clearForRestart();
    });
  }

  /// Kerjakan ulang form
  void _retry() {
    _c.retryInit();
    setState(() => _step = _RunnerStep.fill);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return switch (_step) {
      _RunnerStep.code => RunnerCodeStep(
          showTitle: widget.showTitle,
          codeController: _c.codeController,
          tokenController: _c.tokenController,
          nameController: _c.nameController,
          info: _c.info,
          loading: _loading,
          requiresToken: _c.requiresToken,
          isLoggedIn: _isLoggedIn,
          onSubmitCode: _submitCode,
          onLoadQuestions: _loadQuestions,
        ),
      _RunnerStep.fill => RunnerFillStep(
          info: _c.info!,
          store: _c.store,
          questions: _c.questions,
          isMultiPage: _c.formTypeId == 2 && _c.questions.length > 1,
          currentQuestion: _c.currentQuestion,
          submitting: _submitting,
          errorQuestionIds: _errorQuestionIds,
          onSubmit: _submit,
          onNext: _next,
          onPrevious: () => setState(() => _c.currentQuestion--),
          onAnswerChanged: (qid) =>
              setState(() => _errorQuestionIds.remove(qid)),
          onPickDateTime: _pickDateTime,
        ),
      _RunnerStep.result => RunnerResultView(
          result: _c.result!,
          canRetry: _c.info?.oneResponse != true,
          isLoggedIn: _isLoggedIn,
          onRetry: _retry,
          onReset: _reset,
          onFeedback: () => _openFeedback(_c.result!.formId),
        ),
    };
  }

  /// Lanjut soal berikutnya (multi-page)
  void _next() {
    final q = _c.questions[_c.currentQuestion];
    if (q.isRequired == true && !_c.store.isAnswered(q)) {
      showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
      return;
    }
    setState(() => _c.currentQuestion++);
  }

  Future<void> _pickDateTime(int questionId) async {
    final now = DateTime.now();
    final initial = _c.store.datetimeAnswers[questionId] ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      _c.store.datetimeAnswers[questionId] =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _errorQuestionIds.remove(questionId);
    });
  }

  Future<void> _openFeedback(int formId) async {
    final submitted = await showFeedbackSheet(context, formId: formId);
    if (submitted == true && mounted) {
      showAuthToast(context, 'Feedback terkirim. Terima kasih!');
    }
  }
}
