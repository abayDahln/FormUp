import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form_runner/controllers/form_runner_controller.dart';
import 'package:form_up/features/form_runner/widgets/runner_code_step.dart';
import 'package:form_up/features/form_runner/widgets/runner_exit_dialog.dart';
import 'package:form_up/features/form_runner/widgets/runner_fill_step.dart';
import 'package:form_up/features/form_runner/widgets/runner_screen_shell.dart';

/// Alur: kode → token → jawaban → kembali ke screen awal form
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

enum _RunnerStep { code, fill }

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

  Future<bool> _confirmManualSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Kirim Jawaban?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        content: const Text(
          'Yakin ingin mengumpulkan jawaban sekarang?',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAuthPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
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

  /// Auto submit saat waktu habis: jawaban dikirim langsung lalu kembali ke
  /// screen awal form.
  Future<void> _autoSubmit() async {
    if (_submitting) return;
    await _submitInternal(returnToStartScreen: true);
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
    return _submitInternal(returnToStartScreen: false);
  }

  Future<bool> _submitInternal({
    required bool returnToStartScreen,
  }) async {
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
      await _c.submitAnswers(answers);
      if (!mounted) return false;
      if (returnToStartScreen) {
        AppRouter.of(context).pop();
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitWithConfirmation() async {
    if (_submitting) return;
    final firstUnanswered = _c.store.firstUnansweredIndex(_c.questions);
    if (firstUnanswered != null) {
      setState(() {
        _errorQuestionIds
          ..clear()
          ..addAll(_c.store.unansweredIds(_c.questions));
      });
      _scrollToUnanswered(firstUnanswered);
      showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
      return;
    }

    final confirmed = await _confirmManualSubmit();
    if (!confirmed || !mounted) return;
    await _submitInternal(returnToStartScreen: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoadingOverlay();
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
          onSubmit: _submitWithConfirmation,
          onNext: _next,
          onPrevious: () => setState(() => _c.currentQuestion--),
          onAnswerChanged: (qid) =>
              setState(() => _errorQuestionIds.remove(qid)),
          onPickDateTime: _pickDateTime,
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
}
