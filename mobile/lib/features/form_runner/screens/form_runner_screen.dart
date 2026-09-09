import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/app_toast.dart' hide showAuthToast;
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/exam_lock_service.dart';
import 'package:form_up/core/services/exam_warning_sound.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/services/exam_session_client.dart';
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
    if (mounted) {
      setState(() {
        _timerSeconds = info.timerDuration;
      });
    }
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

class FormRunnerViewState extends State<FormRunnerView> with WidgetsBindingObserver {
  AppRouterDelegate? _router;
  final FormRunnerController _c = FormRunnerController();

  _RunnerStep _step = _RunnerStep.code;
  bool _loading = false;
  bool _submitting = false;
  int _tabSwitchCount = 0;
  ExamSessionClient? _exam;

  // Guard pengaman ujian: overlay/floating app & split-screen.
  Timer? _examGuardTimer;
  bool _sawInactive = false;
  bool _sawPaused = false;
  bool _multiWindowFlagged = false;
  DateTime? _lastWindowBlurAt;
  static const _windowBlurCooldown = Duration(seconds: 10);
  // True bila auto-submit karena limit pelanggaran sudah jalan: bunyi
  // alarm dibiarkan terus sampai dialog ditutup (dispose), tidak ikut
  // berhenti saat resumed. True bila app sedang di luar (background).
  bool _violationSubmitted = false;
  bool _appInBackground = false;

  // ID soal wajib yang belum dijawab (untuk indikator merah saat submit gagal).
  final Set<int> _errorQuestionIds = {};

  bool get _isLoggedIn => _c.isLoggedIn;
  bool get _examActive => _c.info?.isExamMode == true;
  // Pelacakan sesi/pelanggaran ikut server + web: aktif bila isExamMode
  // ATAU detectTabSwitch. Sebelumnya hanya isExamMode sehingga form
  // detectTabSwitch-saja tidak terpantau sama sekali dari mobile.
  bool get _examTracking =>
      _c.info?.isExamMode == true || _c.info?.detectTabSwitch == true;
  bool get _disableCopy => _c.info?.disableCopyPaste == true;
  bool get _detectSwitch => _c.info?.detectTabSwitch == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_examTracking || _step != _RunnerStep.fill) return;
    if (state == AppLifecycleState.inactive) {
      // Kemungkinan overlay/floating app menutup fokus (tanpa pause).
      // Keputusan lapor ditunda sampai resumed: bila ternyata lanjut ke
      // paused, tab_switch yang melapor (anti double-count).
      _sawInactive = true;
      return;
    }
    if (state == AppLifecycleState.paused) {
      _sawPaused = true;
      _appInBackground = true;
      // Langsung bunyikan peringatan tiap keluar app saat ujian —
      // tanpa menunggu limit tercapai.
      unawaited(ExamWarningSound.playDeterrent());
      if (!_detectSwitch) return;
      // Aturan counting server: 1 event per siklus, hanya saat pergi.
      _reportTabSwitch();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _appInBackground = false;
      // Kembali ke form: hentikan bunyi — KECUALI auto-submit karena
      // limit sudah jalan (alarm terus sampai dialog ditutup), agar
      // tidak terasa seperti ke-pause saat dialog muncul.
      if (!_violationSubmitted) {
        unawaited(ExamWarningSound.stop());
      }
      // Kembali tanpa pernah pause = interupsi overlay/floating semata.
      final wasOverlayOnly = _sawInactive && !_sawPaused;
      _sawInactive = false;
      _sawPaused = false;
      if (wasOverlayOnly) _reportWindowBlur();
    }
  }

  /// Lapor 1x keluar aplikasi ke server; auto-submit bila server meminta.
  Future<void> _reportTabSwitch() async {
    final exam = _exam;
    bool serverAutoSubmit = false;
    if (exam != null && _c.formLink != null) {
      serverAutoSubmit = await exam.reportTabSwitch();
      if (mounted) setState(() => _tabSwitchCount = exam.tabSwitchCount);
    } else {
      _tabSwitchCount++;
    }
    final maxSwitch = _c.info?.maxTabSwitch;
    final autoSubmit = _c.info?.autoSubmitOnTabSwitch == true;
    if (!mounted) return;
    if (serverAutoSubmit ||
        (maxSwitch != null &&
            maxSwitch > 0 &&
            _tabSwitchCount >= maxSwitch &&
            autoSubmit)) {
      _violationSubmitted = true;
      await _autoSubmit(violationLimit: true);
      if (mounted) {
        showAppToast(
          context,
          'Jawaban otomatis terkirim',
          type: ToastType.info,
        );
      }
      return;
    }
    if (mounted) {
      showAppToast(
        context,
        'Peringatan mode ujian: jangan keluar aplikasi ($_tabSwitchCount${maxSwitch != null && maxSwitch > 0 ? '/$maxSwitch' : ''})',
        type: ToastType.info,
      );
    }
  }

  /// Lapor 1x gangguan fokus/overlay ke server; auto-submit bila diminta.
  /// Cooldown 10 detik agar interupsi beruntun tidak spam pelanggaran.
  Future<void> _reportWindowBlur() async {
    if (!_examTracking || _step != _RunnerStep.fill) return;
    // Bunyi dulu (deterrent), baru lapor — sama seperti keluar app.
    unawaited(ExamWarningSound.playDeterrent());
    final now = DateTime.now();
    if (_lastWindowBlurAt != null &&
        now.difference(_lastWindowBlurAt!) < _windowBlurCooldown) {
      return;
    }
    _lastWindowBlurAt = now;
    final exam = _exam;
    bool serverAutoSubmit = false;
    if (exam != null && _c.formLink != null) {
      serverAutoSubmit = await exam.reportWindowBlur();
      if (mounted) setState(() => _tabSwitchCount = exam.tabSwitchCount);
    }
    if (!mounted) return;
    if (serverAutoSubmit) {
      _violationSubmitted = true;
      await _autoSubmit(violationLimit: true);
      if (mounted) {
        showAppToast(
          context,
          'Jawaban otomatis terkirim',
          type: ToastType.info,
        );
      }
      return;
    }
    if (mounted) {
      showAppToast(
        context,
        'Peringatan mode ujian: gangguan layar terdeteksi, kembali fokus ke aplikasi',
        type: ToastType.info,
      );
    }
  }

  /// Cek split-screen berkala selama ujian (tiap 5 detik). Dilaporkan 1x
  /// sebagai window_blur sampai user keluar dari split-screen. Merangkap
  /// watchdog bunyi: selama user di luar form, pastikan alarm tetap
  /// berbunyi (pulihkan bila OS menjeda audio).
  void _startExamGuard() {
    _examGuardTimer?.cancel();
    _examGuardTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_examTracking || _step != _RunnerStep.fill) return;
      if (_appInBackground) {
        await ExamWarningSound.ensureLooping();
      }
      bool inMulti = false;
      try {
        inMulti = await ExamLockService.isInMultiWindowMode();
      } catch (_) {
        return;
      }
      if (inMulti && !_multiWindowFlagged) {
        _multiWindowFlagged = true;
        await _reportWindowBlur();
      } else if (!inMulti) {
        _multiWindowFlagged = false;
      }
    });
  }

  /// Lepas seluruh pengaman perangkat + hentikan guard. Wajib di semua
  /// jalur keluar ujian agar FLAG_SECURE tidak bocor ke layar lain.
  Future<void> _releaseExamLock() async {
    _examGuardTimer?.cancel();
    _examGuardTimer = null;
    _multiWindowFlagged = false;
    try {
      await ExamLockService.unlock();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.popBackGuard();
    _exam?.stop();
    unawaited(_releaseExamLock());
    unawaited(ExamWarningSound.dispose());
    _c.dispose();
    super.dispose();
  }

  /// Konfirmasi keluar dari form.
  /// Keluar = langsung keluar tanpa submit (tidak tercatat), Batal = tetap di form.
  Future<bool> _confirmExit() async {
    if (_step != _RunnerStep.fill) return true;
    if (!mounted) return true;
    final action = await showRunnerExitDialog(context);
    return action == RunnerExitAction.exitWithoutSubmit;
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
        title:  Text(
          'Kirim Jawaban?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Theme.of(ctx).colorScheme.onSurface,
          ),
        ),
        content:  Text(
          'Yakin ingin mengumpulkan jawaban sekarang?',
          style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:  Text(
              'Batal',
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
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
      // Pelacakan ujian: kunci perangkat (khusus isExamMode) + mulai sesi
      // server + guard overlay. Sesi server jalan juga untuk form
      // detectTabSwitch-saja (paritas web + aturan terima server).
      if (_examTracking && _c.formLink != null) {
        if (_examActive) {
          // FLAG_SECURE + tolak sentuhan overlay (best-effort, tidak blokir).
          unawaited(ExamLockService.lock());
        }
        final exam = ExamSessionClient(
          formLink: _c.formLink!,
          respondentName: _c.isLoggedIn ? null : _c.nameController.text,
        );
        _exam = exam;
        // Sesi baru: matikan sisa bunyi sesi lama, reset flag.
        await ExamWarningSound.stop();
        ExamWarningSound.reset();
        _violationSubmitted = false;
        _appInBackground = false;
        unawaited(ExamWarningSound.prime());
        await exam.start();
        if (mounted) setState(() => _tabSwitchCount = exam.tabSwitchCount);
        _startExamGuard();
      }
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Auto submit: langsung kirim hasil apa adanya (selesai atau tidak
  /// selesai), tidak ada penambahan waktu. Bila karena pelanggaran
  /// mencapai limit ([violationLimit]), volume dimaksimalkan + bunyi
  /// peringatan diputar sebelum mengirim.
  Future<void> _autoSubmit({bool violationLimit = false}) async {
    if (_submitting) return;
    if (violationLimit) {
      await ExamWarningSound.playLimitWarning();
    }
    final answers = _c.store.collectAutoAnswers(_c.questions);
    setState(() => _submitting = true);
    try {
      await _c.submitAnswers(
        answers,
        isAutoSubmit: true,
        examSessionId: _exam?.sessionId,
        tabSwitchCount: _examTracking ? _tabSwitchCount : null,
      );
    } catch (e) {
      if (!mounted) return;
      // Tetap tampilkan dialog selesai meski submit gagal (mis. sudah pernah submit)
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      _exam?.stop();
      await _releaseExamLock();
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => violationLimit
          ? _ViolationDoneDialog(onClose: () => Navigator.pop(ctx))
          : AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text("Form Selesai",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: Theme.of(ctx).colorScheme.onSurface)),
              content: Text("Waktu pengerjaan telah habis. Jawaban telah dikirim.",
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              actions: [
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: kAuthPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Tutup"),
                ),
              ],
            ),
    );
    if (!mounted) return;
    AppRouter.of(context).pop();
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
  // Future<bool> _submit() async {
  //   return _submitInternal(returnToStartScreen: false);
  // }

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
    // Cegah submit kosong: belum isi apapun tetap tercatat sebagai sudah mengerjakan
    if (!_c.store.hasAnyAnswer(_c.questions)) {
      showAuthToast(context, "Isi minimal satu jawaban sebelum mengirim", isError: true);
      return false;
    }
    final answers = _c.store.collectValidatedAnswers(_c.questions);
    if (answers == null) {
      showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
      return false;
    }

    setState(() => _submitting = true);
    try {
      await _c.submitAnswers(
        answers,
        examSessionId: _exam?.sessionId,
        tabSwitchCount: _examTracking ? _tabSwitchCount : null,
      );
      _exam?.stop();
      await _releaseExamLock();
      // Kumpul manual oleh user yang hadir: hentikan bunyi bila menyala.
      await ExamWarningSound.stop();
      if (!mounted) return false;
      if (returnToStartScreen) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title:  Text("Jawaban Terkirim", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: kFontBold, color: Theme.of(ctx).colorScheme.onSurface)),
            content:  Text("Jawaban sudah terkirim.", style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kAuthPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Tutup"),
              ),
            ],
          ),
        );
        if (!mounted) return true;
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
    if (!_c.store.hasAnyAnswer(_c.questions)) {
      showAuthToast(context, "Isi minimal satu jawaban sebelum mengirim", isError: true);
      return;
    }

    final confirmed = await _confirmManualSubmit();
    if (!confirmed || !mounted) return;
    await _submitInternal(returnToStartScreen: true);
  }

  Color? _parseHex(String? hex) {
    if (hex == null || !hex.startsWith('#') || hex.length != 7) return null;
    try { return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000); } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoadingOverlay();
    // FEAT-9: apply theme background if present
    final themeBg = _parseHex(_c.info?.themeBackgroundColor);
    Widget fillWidget = RunnerFillStep(
          info: _c.info!,
          store: _c.store,
          questions: _c.questions,
          isMultiPage: _c.formTypeId == 2 && _c.questions.length > 1,
          disablePaste: _disableCopy && _step == _RunnerStep.fill,
          currentQuestion: _c.currentQuestion,
          submitting: _submitting,
          errorQuestionIds: _errorQuestionIds,
          onSubmit: _submitWithConfirmation,
          onNext: _next,
          onPrevious: () => setState(() => _c.currentQuestion--),
          onJumpTo: (idx) => setState(() => _c.currentQuestion = idx),
          onAnswerChanged: (qid) =>
              setState(() => _errorQuestionIds.remove(qid)),
          onPickDateTime: _pickDateTime,
        );
    // FEAT-6: wrap disabled copy-paste via SelectionContainer disabled
    if (_disableCopy && _step == _RunnerStep.fill) {
      fillWidget = SelectionContainer.disabled(child: fillWidget);
    }
    if (themeBg != null && _step == _RunnerStep.fill) {
      fillWidget = Container(color: themeBg, child: fillWidget);
    }
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
      _RunnerStep.fill => Column(
          children: [
            if (_examActive)
              Container(
                width: double.infinity,
                color: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _detectSwitch
                            ? 'Mode Ujian aktif • Pelanggaran ($_tabSwitchCount${_c.info?.maxTabSwitch != null && _c.info!.maxTabSwitch! > 0 ? '/${_c.info!.maxTabSwitch}' : ''})'
                            : 'Mode Ujian aktif',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_disableCopy) const Icon(Icons.content_copy, size: 12, color: Colors.white70),
                  ],
                ),
              ),
            Expanded(child: fillWidget),
          ],
        ),
    };
  }

  /// Lanjut soal berikutnya (multi-page) - bebas pindah, validasi hanya saat submit
  void _next() {
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

/// Dialog selesai karena ketahuan menyontek (batas pelanggaran tercapai):
/// bernuansa merah peringatan, hanya ada tombol Tutup yang terkunci
/// selama 5 detik (hitungan mundur). Bunyi alarm terus menyala sampai
/// dialog ini ditutup.
class _ViolationDoneDialog extends StatefulWidget {
  final VoidCallback onClose;

  const _ViolationDoneDialog({required this.onClose});

  @override
  State<_ViolationDoneDialog> createState() => _ViolationDoneDialogState();
}

class _ViolationDoneDialogState extends State<_ViolationDoneDialog> {
  static const _lockSeconds = 5;
  int _remaining = _lockSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining > 0) _remaining--;
      });
      if (_remaining <= 0) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unlocked = _remaining <= 0;
    final red =
        Theme.of(context).brightness == Brightness.dark
            ? Colors.red.shade400
            : Colors.red.shade700;
    return PopScope(
      // Tombol back HP juga dikunci selama hitungan mundur.
      canPop: unlocked,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: red, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: red, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Ketahuan Menyontek!",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: red,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Batas pelanggaran tercapai. Jawaban telah dikirim otomatis.",
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: unlocked ? red : cs.surfaceContainerHighest,
              foregroundColor:
                  unlocked ? Colors.white : cs.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: unlocked ? widget.onClose : null,
            child: Text(unlocked
                ? "Tutup"
                : "Tutup ($_remaining)"),
          ),
        ],
      ),
    );
  }
}
