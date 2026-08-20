import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'auth_widgets.dart';
import 'answer_fields.dart';
import 'rich_editor.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';
import '../services/public_form_service.dart';
import '../app_router.dart';

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
    return Scaffold(
      backgroundColor: kAuthBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          // Lewat popRoute agar back guard (dialog keluar form) tetap jalan.
          onPressed: () => AppRouter.of(context).popRoute(),
        ),
        title: const Text(
          "Kerjakan Form",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        actions: [
          if (_timerSeconds != null && _timerSeconds! > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: _CountdownBadge(
                  key: ValueKey(_timerSeconds),
                  seconds: _timerSeconds!,
                  onExpired: _onTimerExpired,
                ),
              ),
            ),
        ],
      ),
      body: AuthBackground(
        child: SafeArea(
          child: FormRunnerView(
            key: _viewKey,
            initialCode: widget.initialCode,
            initialToken: widget.initialToken,
            onInfoLoaded: _onInfoLoaded,
          ),
        ),
      ),
    );
  }
}

class FormRunnerViewState extends State<FormRunnerView> {
  AppRouterDelegate? _router;

  final _codeController = TextEditingController();
  final _tokenController = TextEditingController();
  final _nameController = TextEditingController();

  _RunnerStep _step = _RunnerStep.code;
  bool _loading = false;
  bool _submitting = false;

  // 1 Single, 2 Multi
  int _formTypeId = 1;
  int _currentQuestion = 0;

  String? _formLink;
  PublicFormInfo? _info;
  List<PublicQuestion> _questions = [];
  PublicFormResult? _result;

  final Map<int, TextEditingController> _textAnswers = {};
  final Map<int, int?> _singleAnswers = {};
  final Map<int, Set<int>> _multiAnswers = {};
  final Map<int, String?> _tfAnswers = {};
  final Map<int, DateTime?> _datetimeAnswers = {};
  final Map<int, FocusNode> _essayFocusNodes = {};
  final List<GlobalKey> _questionKeys = [];

  bool get _requiresToken => _info?.requiresToken ?? false;
  bool get _isLoggedIn => AuthService.token != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      _tokenController.text = widget.initialToken!;
    }
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeController.text = widget.initialCode!;
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
    _codeController.dispose();
    _tokenController.dispose();
    _nameController.dispose();
    for (final c in _textAnswers.values) {
      c.dispose();
    }
    for (final f in _essayFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// Konfirmasi keluar dari form.
  /// Mengembalikan true bila boleh keluar (sudah kirim & keluar), false bila batal.
  Future<bool> _confirmExit() async {
    // Hanya intercept saat sedang mengerjakan (fill step)
    if (_step != _RunnerStep.fill) return true;
    if (!mounted) return true;

    final exit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Keluar dari Form?",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        content: const Text(
          "Apakah Anda yakin ingin keluar? Jawaban Anda akan dikumpulkan.",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batalkan",
                style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAuthPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final ok = await _submit();
              if (ctx.mounted) Navigator.pop(ctx, ok);
            },
            child: const Text("Kirim dan Keluar"),
          ),
        ],
      ),
    );
    return exit ?? false;
  }

  /// Panggil saat timer form habis (dari countdown di AppBar).
  Future<void> handleTimerExpired() async {
    await _autoSubmit();
  }

  Future<void> _submitCode() async {
    if (_loading) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      showAuthToast(context, "Masukkan kode form terlebih dahulu", isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final info = await PublicFormService.getFormInfo(code);
      if (!mounted) return;
      // Pemilik tidak boleh mengisi form sendiri.
      if (info.isOwner) {
        setState(() {
          _formLink = null;
          _info = null;
        });
        showAuthToast(
          context,
          "Anda tidak dapat mengisi form yang Anda buat sendiri",
          isError: true,
        );
        return;
      }
      setState(() {
        _formLink = code;
        _info = info;
      });
      widget.onInfoLoaded?.call(info);
      if (info.requiresToken) {
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
      final questions = await PublicFormService.getQuestions(
        _formLink!,
        token: _tokenController.text.trim().isEmpty
            ? null
            : _tokenController.text.trim(),
      );
      if (!mounted) return;
      _initAnswers(questions);
      setState(() {
        _questions = questions;
        _formTypeId = _info?.formTypeId ?? 1;
        _currentQuestion = 0;
        _step = _RunnerStep.fill;
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _initAnswers(List<PublicQuestion> questions) {
    _textAnswers.clear();
    _singleAnswers.clear();
    _multiAnswers.clear();
    _tfAnswers.clear();
    _datetimeAnswers.clear();
    _essayFocusNodes.clear();
    _questionKeys
      ..clear()
      ..addAll([for (var i = 0; i < questions.length; i++) GlobalKey()]);
    for (final q in questions) {
      switch (q.typeId) {
        case 1: // Essay
          _textAnswers[q.id] = TextEditingController();
          _essayFocusNodes[q.id] = FocusNode();
          break;
        case 4: // Date Time
          _datetimeAnswers[q.id] = null;
          break;
        case 5: // True/False
          _tfAnswers[q.id] = null;
          break;
        case 2: // Multiple Choice
          _singleAnswers[q.id] = null;
          break;
        case 3: // Checkbox
          _multiAnswers[q.id] = {};
          break;
      }
    }
  }

  /// Auto submit saat waktu habis
  Future<void> _autoSubmit() async {
    if (_submitting) return;
    showAuthToast(context, "Waktu pengerjaan telah habis, jawaban dikirim", isError: true);
    await _submit();
  }

  /// Index soal wajib pertama yang belum dijawab (urut dari atas), atau null.
  int? _firstUnansweredIndex() {
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.isRequired == true && !_isAnswered(q)) return i;
    }
    return null;
  }

  /// Scroll ke soal belum dijawab pertama dan fokus ke field esai-nya (jika ada).
  void _scrollToUnanswered(int index) {
    if (_formTypeId == 2 && _questions.length > 1) {
      // Mode multi-page: pindah ke halaman soal tsb.
      setState(() => _currentQuestion = index);
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusEssayIfAny(index));
      return;
    }
    // Mode single-page: scroll ke kartu soal tsb lalu fokus.
    final ctx = _questionKeys[index].currentContext;
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
    final q = _questions[index];
    if (q.typeId == 1) {
      _essayFocusNodes[q.id]?.requestFocus();
    }
  }

  /// Submit jawaban. Mengembalikan true bila berhasil, false bila gagal/validasi.
  Future<bool> _submit() async {
    if (_submitting) return false;
    final firstUnanswered = _firstUnansweredIndex();
    if (firstUnanswered != null) {
      _scrollToUnanswered(firstUnanswered);
      showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
      return false;
    }
    final answers = <Map<String, dynamic>>[];
    for (final q in _questions) {
      switch (q.typeId) {
        case 1: // Essay
          final text = _textAnswers[q.id]?.text.trim() ?? '';
          if (q.isRequired == true && text.isEmpty) {
            showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
            return false;
          }
          if (text.isNotEmpty) {
            answers.add({'questionId': q.id, 'answerValue': text});
          }
          break;
        case 2: // Multiple Choice
          final optionId = _singleAnswers[q.id];
          if (q.isRequired == true && optionId == null) {
            showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
            return false;
          }
          if (optionId != null) {
            answers.add({'questionId': q.id, 'optionId': optionId});
          }
          break;
        case 3: // Checkbox
          final selected = _multiAnswers[q.id] ?? {};
          if (q.isRequired == true && selected.isEmpty) {
            showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
            return false;
          }
          for (final oid in selected) {
            answers.add({'questionId': q.id, 'optionId': oid});
          }
          break;
        case 4: // Date Time
          final dt = _datetimeAnswers[q.id];
          if (q.isRequired == true && dt == null) {
            showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
            return false;
          }
          if (dt != null) {
            answers.add({
              'questionId': q.id,
              'answerValue': _formatDateTime(dt),
            });
          }
          break;
        case 5: // True/False
          final tf = _tfAnswers[q.id];
          if (q.isRequired == true && tf == null) {
            showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
            return false;
          }
          if (tf != null) {
            answers.add({'questionId': q.id, 'answerValue': tf});
          }
          break;
      }
    }

    setState(() => _submitting = true);
    try {
      final data = await PublicFormService.submit(
        _formLink!,
        token: _tokenController.text.trim().isEmpty
            ? null
            : _tokenController.text.trim(),
        respondentName: _isLoggedIn ? null : _nameController.text,
        answers: answers,
      );
      final responseId = data['responseId'] as int;

      if (!mounted) return false;

      // Hasil hanya untuk user login
      if (!_isLoggedIn) {
        showAuthToast(context, "Jawaban berhasil dikirim");
        await _reset();
        return true;
      }

      final result = await PublicFormService.getResult(_formLink!, responseId);
      if (!mounted) return false;
      setState(() {
        _result = result;
        _step = _RunnerStep.result;
      });
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
      _info = null;
      _questions = [];
      _result = null;
      _formLink = null;
      _currentQuestion = 0;
      _tokenController.clear();
      _nameController.clear();
    });
  }

  /// Kerjakan ulang form
  void _retry() {
    for (final c in _textAnswers.values) {
      c.dispose();
    }
    _initAnswers(_questions);
    setState(() {
      _result = null;
      _currentQuestion = 0;
      _step = _RunnerStep.fill;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return switch (_step) {
      _RunnerStep.code => _buildCodeStep(),
      _RunnerStep.fill => _buildFillStep(),
      _RunnerStep.result => _buildResultStep(),
    };
  }

  Widget _buildCodeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTitle) ...[
            const AuthTitle(
              title: "Kerjakan Form",
              subtitle: "Masukkan kode form dari pemilik untuk mulai mengerjakan.",
            ),
            const SizedBox(height: 32),
          ],
          AuthCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _codeController,
                  hint: "Kode form",
                  icon: Icons.link,
                ),
                if (_info != null) ...[
                  const SizedBox(height: 18),
                  _buildFormInfoCard(),
                ],
                if (_requiresToken) ...[
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _tokenController,
                    hint: "Token akses",
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Form ini dilindungi token. Masukkan token yang diberikan pemilik form.",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                if (!_isLoggedIn && _info != null && !_info!.requiresLogin) ...[
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _nameController,
                    hint: "Nama Anda (opsional)",
                    icon: Icons.person_outline,
                  ),
                ],
                const SizedBox(height: 22),
                AuthPrimaryButton(
                  label: _info == null ? "Lanjut" : "Mulai Mengerjakan",
                  loading: _loading,
                  onPressed: _info == null ? _submitCode : _loadQuestions,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Butuh bantuan? Hubungi pemilik form untuk mendapatkan kode.",
            style: TextStyle(fontSize: 12, color: Colors.black45),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFormInfoCard() {
    final info = _info!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrimarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAuthPrimary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.description_outlined, size: 20, color: kAuthPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichTextView(
                  text: info.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
                if (info.description != null && info.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  RichTextView(
                    text: info.description!,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (info.oneResponse) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 13,
                        color: Color(0xFFB26A00),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "Form ini hanya dapat diisi satu kali.",
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB26A00),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFillStep() {
    if (_formTypeId == 2 && _questions.length > 1) {
      return _buildMultiPageFill();
    }
    return _buildSinglePageFill();
  }

  /// Mode Single Page
  Widget _buildSinglePageFill() {
    final info = _info!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              _buildFormHeaderCard(info),
              const SizedBox(height: 16),
              for (var i = 0; i < _questions.length; i++) ...[
                _buildQuestionCard(i),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            color: Colors.white,
            child: AuthPrimaryButton(
              label: _submitting ? "Mengirim..." : "Kirim Jawaban",
              loading: _submitting,
              onPressed: _submit,
            ),
          ),
        ),
      ],
    );
  }

  /// Mode Multi Page
  Widget _buildMultiPageFill() {
    final info = _info!;
    final isLast = _currentQuestion == _questions.length - 1;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Soal ${_currentQuestion + 1} dari ${_questions.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                '${((_currentQuestion + 1) / _questions.length * 100).round()}%',
                style: const TextStyle(fontSize: 12, color: kAuthPrimary),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            children: [
              if (_currentQuestion == 0) ...[
                _buildFormHeaderCard(info),
                const SizedBox(height: 16),
              ],
              _buildQuestionCard(_currentQuestion),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentQuestion > 0
                        ? () => setState(() => _currentQuestion--)
                        : null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kAuthPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text(
                      "Sebelumnya",
                      style: TextStyle(color: kAuthPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AuthPrimaryButton(
                    label: isLast
                        ? (_submitting ? "Mengirim..." : "Kirim Jawaban")
                        : "Berikutnya",
                    showArrow: false,
                    loading: _submitting,
                    onPressed: isLast ? _submit : _next,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Kartu header form
  Widget _buildFormHeaderCard(PublicFormInfo info) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner form (jika diisi)
          if (info.bannerImage != null && info.bannerImage!.trim().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  profileImageUrl(info.bannerImage),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, _, _) => Container(
                    color: kPrimarySoft,
                    child: const Icon(
                      Icons.image_outlined,
                      size: 36,
                      color: kAuthPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          RichTextView(
            text: info.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          // Deskripsi form (jika diisi)
          if (info.description != null && info.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            RichTextView(
              text: info.description!,
              ignoreInlineFontSize: true,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
          if (info.timerDuration != null && info.timerDuration! > 0) ...[
            const SizedBox(height: 6),
            Text(
              "⏱ ${_formatDuration(info.timerDuration!)}",
              style: const TextStyle(fontSize: 12, color: kAuthPrimary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            "${_questions.length} pertanyaan · ${_questions.where((q) => q.isRequired == true).length} wajib dijawab",
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  /// Lanjut soal berikutnya
  void _next() {
    final q = _questions[_currentQuestion];
    if (q.isRequired == true && !_isAnswered(q)) {
      showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
      return;
    }
    setState(() => _currentQuestion++);
  }

  bool _isAnswered(PublicQuestion q) {
    switch (q.typeId) {
      case 1:
        return (_textAnswers[q.id]?.text.trim() ?? '').isNotEmpty;
      case 2:
        return _singleAnswers[q.id] != null;
      case 3:
        return (_multiAnswers[q.id] ?? {}).isNotEmpty;
      case 4:
        return _datetimeAnswers[q.id] != null;
      case 5:
        return _tfAnswers[q.id] != null;
      default:
        return true;
    }
  }

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    return Container(
      key: _questionKeys[index],
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RichTextView(
                    text: q.question,
                    prefix: '${index + 1}. ',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
                if (q.isRequired == true)
                  const Text(
                    "*",
                    style: TextStyle(color: Color(0xFFC0392B), fontSize: 16),
                  ),
              ],
            ),
          ),
          // Gambar soal (jika dilampirkan)
          if (q.questionImage != null && q.questionImage!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _QuestionImage(url: q.questionImage!),
          ],
          // Audio soal (jika dilampirkan)
          if (q.questionAudio != null && q.questionAudio!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _QuestionAudio(url: q.questionAudio!),
          ],
          const SizedBox(height: 12),
          AnswerFields(
            typeId: q.typeId,
            options: [
              for (final o in q.options) AnswerOption(o.id, o.optionText),
            ],
            essayController: _textAnswers[q.id],
            essayFocusNode: _essayFocusNodes[q.id],
            onEssayChanged: (_) => setState(() {}),
            singleValue: _singleAnswers[q.id],
            multiValue: _multiAnswers[q.id] ?? {},
            tfValue: _tfAnswers[q.id],
            dateLabel: _datetimeAnswers[q.id] == null
                ? null
                : _formatDateTime(_datetimeAnswers[q.id]!),
            onSingleChanged: (v) => setState(() => _singleAnswers[q.id] = v),
            onMultiChanged: (v) => setState(() => _multiAnswers[q.id] = v),
            onTfChanged: (v) => setState(() => _tfAnswers[q.id] = v),
            onPickDateTime: () => _pickDateTime(q.id),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime(int questionId) async {
    final now = DateTime.now();
    final initial = _datetimeAnswers[questionId] ?? now;
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
      _datetimeAnswers[questionId] =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Widget _buildResultStep() {
    final result = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result.showScore) ...[
            _buildScoreCard(result),
            const SizedBox(height: 16),
          ],
          Text(
            result.showScore ? "Pembahasan" : "Jawaban Anda",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (result.answers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                "Belum ada jawaban.",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            )
          else
            for (var i = 0; i < result.answers.length; i++) ...[
              _buildResultCard(i, result.answers[i], result.showScore),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 8),
          if (_info?.oneResponse != true) ...[
            AuthPrimaryButton(
              label: "Kerjakan Ulang",
              showArrow: false,
              onPressed: _retry,
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, size: 18, color: kAuthPrimary),
            label: const Text(
              "Kerjakan Form Lain",
              style: TextStyle(color: kAuthPrimary),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kAuthPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (_isLoggedIn) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openFeedback(result.formId),
              icon: const Icon(Icons.message_outlined, size: 18, color: kAuthPrimary),
              label: const Text(
                "Kirim Feedback",
                style: TextStyle(color: kAuthPrimary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kAuthPrimary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openFeedback(int formId) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FeedbackSheet(formId: formId),
    );
    if (submitted == true && mounted) {
      showAuthToast(context, 'Feedback terkirim. Terima kasih!');
    }
  }

  Widget _buildScoreCard(PublicFormResult result) {
    final score = result.score;
    final color = score == null
        ? Colors.grey
        : (score >= 75
              ? const Color(0xFF2E7D32)
              : score >= 50
                  ? const Color(0xFFB26A00)
                  : const Color(0xFFC0392B));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        children: [
          Text(
            "Skor Anda",
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            score == null ? "—" : "${score.toStringAsFixed(1)}%",
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _scoreStat(
                "${result.correctCount}",
                "Benar",
                const Color(0xFF2E7D32),
              ),
              _scoreStat(
                "${result.wrongCount}",
                "Salah",
                const Color(0xFFC0392B),
              ),
              _scoreStat(
                "${result.answeredCount}",
                "Dijawab",
                kAuthPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildResultCard(int index, PublicResultAnswer a, bool showScore) {
    final answered = a.answerText != null && a.answerText!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichTextView(
                  text: a.question,
                  prefix: '${index + 1}. ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (showScore && a.isCorrect != null)
                Icon(
                  a.isCorrect! ? Icons.check_circle : Icons.cancel,
                  color: a.isCorrect! ? const Color(0xFF2E7D32) : const Color(0xFFC0392B),
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 10),
          ResultOptionsList(
            options: a.options,
            answerText: a.answerText,
            correctAnswer: a.correctAnswer,
            showScore: showScore,
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Jawaban Anda",
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
                const SizedBox(height: 4),
                if (answered)
                  RichTextView(
                    text: a.answerText!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  )
                else
                  const Text(
                    "Tidak dijawab",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          if (showScore &&
              a.correctAnswer != null &&
              a.correctAnswer!.isNotEmpty &&
              a.correctAnswer != a.answerText) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F4E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Jawaban Benar",
                    style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
                  ),
                  const SizedBox(height: 4),
                  RichTextView(
                    text: a.correctAnswer!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return "${local.day} ${months[local.month - 1]} ${local.year}, $hh:$mm";
  }

  /// Format durasi dari detik menjadi "X jam Y menit" / "Y menit"
  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0 && m > 0) return "$h jam $m menit";
    if (h > 0) return "$h jam";
    if (m > 0) return "$m menit";
    return "$seconds detik";
  }
}

/// Gambar soal
class _QuestionImage extends StatelessWidget {
  final String url;

  const _QuestionImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 220),
        color: kPrimarySoft,
        child: Image.network(
          profileImageUrl(url),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox(
            height: 140,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.grey,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pemutar audio soal
class _QuestionAudio extends StatefulWidget {
  final String url;

  const _QuestionAudio({required this.url});

  @override
  State<_QuestionAudio> createState() => _QuestionAudioState();
}

class _QuestionAudioState extends State<_QuestionAudio> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration? _duration;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _playing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.setSource(UrlSource(profileImageUrl(widget.url)));
      await _player.resume();
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = (_duration ?? Duration.zero).inMilliseconds;
    final posMs = _position.inMilliseconds.clamp(0, maxMs).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggle,
            icon: Icon(
              _playing ? Icons.pause_circle : Icons.play_circle,
              color: kAuthPrimary,
              size: 32,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Audio Soal",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Slider(
                  value: maxMs == 0 ? 0 : posMs,
                  max: maxMs == 0 ? 1 : maxMs.toDouble(),
                  activeColor: kAuthPrimary,
                  onChanged: maxMs == 0
                      ? null
                      : (v) async {
                          final t = Duration(milliseconds: v.round());
                          await _player.seek(t);
                          setState(() => _position = t);
                        },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            maxMs == 0 ? _fmt(_position) : _fmt(_duration!),
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

const _feedbackReasons = <String>[
  'General Feedback',
  'Inappropriate Content',
  'Misleading Information',
  'Bug / Technical Issue',
];

/// Countdown mandiri (durasi dalam detik)
class _CountdownBadge extends StatefulWidget {
  final int seconds;
  final VoidCallback onExpired;

  const _CountdownBadge({
    super.key,
    required this.seconds,
    required this.onExpired,
  });

  @override
  State<_CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<_CountdownBadge> {
  late int _secondsLeft;
  Timer? _timer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        _secondsLeft = 0;
        if (!_expired) {
          _expired = true;
          setState(() {});
          widget.onExpired();
        }
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _label {
    final h = (_secondsLeft ~/ 3600).toString().padLeft(2, '0');
    final m = ((_secondsLeft % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final danger = _secondsLeft <= 60;
    final color = danger ? const Color(0xFFC0392B) : kAuthPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFDE8E6) : const Color(0xFFE2F3F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet feedback
class _FeedbackSheet extends StatefulWidget {
  final int formId;

  const _FeedbackSheet({required this.formId});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  String _reason = _feedbackReasons.first;
  final _descController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      showAuthToast(context, 'Deskripsi feedback wajib diisi', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await FormService.submitFeedback(
        widget.formId,
        reason: _reason,
        description: desc,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kirim Feedback',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final r in _feedbackReasons)
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _reason = v);
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Jelaskan feedback atau masalah Anda...',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kirim Feedback'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
