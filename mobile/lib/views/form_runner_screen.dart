import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'answer_fields.dart';
import 'rich_editor.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';
import '../services/public_form_service.dart';
import '../app_router.dart';

/// Alur: masukkan kode → (token jika wajib) → isi jawaban → lihat hasil.
/// Mesin alur ini dipakai di tab "Form" maupun halaman kerjakan yang di-push.
class FormRunnerView extends StatefulWidget {
  final String? initialCode;
  final bool showTitle;

  const FormRunnerView({
    super.key,
    this.initialCode,
    this.showTitle = true,
  });

  @override
  State<FormRunnerView> createState() => _FormRunnerViewState();
}

/// Halaman mengerjakan form (dari search bar home) — AppBar + tombol kembali.
class FormRunnerScreen extends StatefulWidget {
  final String? initialCode;

  const FormRunnerScreen({super.key, this.initialCode});

  @override
  State<FormRunnerScreen> createState() => _FormRunnerScreenState();
}

enum _RunnerStep { code, fill, result }

class _FormRunnerScreenState extends State<FormRunnerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthBg,
      appBar: AppBar(
        backgroundColor: kAuthBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title: const Text(
          "Kerjakan Form",
          style: TextStyle(fontFamily: kFontBold, color: Colors.black87),
        ),
      ),
      body: AuthBackground(
        child: SafeArea(
          child: FormRunnerView(initialCode: widget.initialCode),
        ),
      ),
    );
  }
}

class _FormRunnerViewState extends State<FormRunnerView> {
  final _codeController = TextEditingController();
  final _tokenController = TextEditingController();
  final _nameController = TextEditingController();

  _RunnerStep _step = _RunnerStep.code;
  bool _loading = false;
  bool _submitting = false;

  // 1 = Single Page (scroll semua soal), 2 = Multi Page (next/prev per soal).
  int _formTypeId = 1;
  int _currentQuestion = 0;

  String? _formLink;
  PublicFormInfo? _info;
  List<PublicQuestion> _questions = [];
  PublicFormResult? _result;

  // State jawaban per pertanyaan.
  final Map<int, TextEditingController> _textAnswers = {};
  final Map<int, int?> _singleAnswers = {}; // MC: optionId
  final Map<int, Set<int>> _multiAnswers = {}; // Checkbox: set optionId
  final Map<int, String?> _tfAnswers = {}; // Benar / Salah
  final Map<int, DateTime?> _datetimeAnswers = {};

  bool get _requiresToken => _info?.requiresToken ?? false;
  bool get _isLoggedIn => AuthService.token != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeController.text = widget.initialCode!;
      _submitCode();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _tokenController.dispose();
    _nameController.dispose();
    for (final c in _textAnswers.values) {
      c.dispose();
    }
    super.dispose();
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
      // Pemilik tidak boleh mengisi form sendiri — jangan lanjut ke token/soal.
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
      if (info.requiresToken) {
        // Tetap di fase code, area token ditampilkan setelah info dimuat.
        setState(() => _step = _RunnerStep.code);
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
    for (final q in questions) {
      switch (q.typeId) {
        case 1: // Essay
          _textAnswers[q.id] = TextEditingController();
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

  /// Waktu habis — kirim jawaban apa adanya (dipaksa otomatis).
  Future<void> _autoSubmit() async {
    if (_submitting) return;
    showAuthToast(context, "Waktu pengerjaan telah habis, jawaban dikirim", isError: true);
    await _submit();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final answers = <Map<String, dynamic>>[];
    for (final q in _questions) {
      switch (q.typeId) {
        case 1: // Essay
          final text = _textAnswers[q.id]?.text.trim() ?? '';
          if (q.isRequired == true && text.isEmpty) {
            showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
            return;
          }
          if (text.isNotEmpty) {
            answers.add({'questionId': q.id, 'answerValue': text});
          }
          break;
        case 2: // Multiple Choice
          final optionId = _singleAnswers[q.id];
          if (q.isRequired == true && optionId == null) {
            showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
            return;
          }
          if (optionId != null) {
            answers.add({'questionId': q.id, 'optionId': optionId});
          }
          break;
        case 3: // Checkbox
          final selected = _multiAnswers[q.id] ?? {};
          if (q.isRequired == true && selected.isEmpty) {
            showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
            return;
          }
          for (final oid in selected) {
            answers.add({'questionId': q.id, 'optionId': oid});
          }
          break;
        case 4: // Date Time
          final dt = _datetimeAnswers[q.id];
          if (q.isRequired == true && dt == null) {
            showAuthToast(context, "Pertanyaan wajib belum dijawab", isError: true);
            return;
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
            return;
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

      if (!mounted) return;

      // Hasil hanya bisa diambil user login (pemilik respons). Guest tanpa
      // akun hanya mendapat konfirmasi bahwa jawaban terkirim.
      if (!_isLoggedIn) {
        showAuthToast(context, "Jawaban berhasil dikirim");
        await _reset();
        return;
      }

      final result = await PublicFormService.getResult(_formLink!, responseId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _step = _RunnerStep.result;
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
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

  /// Kerjakan ulang form yang sama (hanya saat oneResponse = false).
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

  // ===== STEP 1: Input kode + token =====
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

  // ===== STEP 2: Isi jawaban =====
  Widget _buildFillStep() {
    if (_formTypeId == 2 && _questions.length > 1) {
      return _buildMultiPageFill();
    }
    return _buildSinglePageFill();
  }

  /// Jumlah soal yang sudah dijawab (untuk progress bar).
  int _answeredCount() {
    var n = 0;
    for (final q in _questions) {
      switch (q.typeId) {
        case 1: // Essay
          if ((_textAnswers[q.id]?.text.trim() ?? '').isNotEmpty) n++;
          break;
        case 2: // Multiple Choice
          if (_singleAnswers[q.id] != null) n++;
          break;
        case 3: // Checkbox
          if ((_multiAnswers[q.id] ?? {}).isNotEmpty) n++;
          break;
        case 4: // Date Time
          if (_datetimeAnswers[q.id] != null) n++;
          break;
        case 5: // True/False
          if (_tfAnswers[q.id] != null) n++;
          break;
      }
    }
    return n;
  }

  /// Header sticky: judul form + progress bar (X / Y terjawab, persen).
  Widget _buildProgressHeader() {
    final total = _questions.length;
    final answered = _answeredCount();
    final pct = total == 0 ? 0 : (answered / total * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _info?.title ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$answered / $total Terjawab ($pct%)',
                style: const TextStyle(fontSize: 12, color: kAuthPrimary),
              ),
              if ((_info?.timerDuration ?? 0) > 0) ...[
                const SizedBox(width: 8),
                _CountdownBadge(
                  minutes: _info!.timerDuration!,
                  onExpired: _autoSubmit,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : answered / total,
              minHeight: 6,
              backgroundColor: const Color(0xFFD8DEDE),
              color: kAuthPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Single Page: semua soal tampil dalam satu scroll vertikal.
  Widget _buildSinglePageFill() {
    final info = _info!;
    return Column(
      children: [
        _buildProgressHeader(),
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

  /// Multi Page: satu soal per halaman, navigasi "Sebelumnya" / "Berikutnya".
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentQuestion + 1) / _questions.length,
              minHeight: 6,
              backgroundColor: const Color(0xFFD8DEDE),
              color: kAuthPrimary,
            ),
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

  /// Kartu header form (judul, timer, jumlah soal) di tahap isi jawaban.
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
          RichTextView(
            text: info.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          if (info.timerDuration != null && info.timerDuration! > 0) ...[
            const SizedBox(height: 6),
            Text(
              "⏱ ${info.timerDuration} menit",
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

  /// Lanjut ke soal berikutnya (validasi soal wajib saat ini).
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
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: kPrimarySoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: kAuthPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichTextView(
                  text: q.question,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
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
          const SizedBox(height: 12),
          AnswerFields(
            typeId: q.typeId,
            options: [
              for (final o in q.options) AnswerOption(o.id, o.optionText),
            ],
            essayController: _textAnswers[q.id],
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

  // ===== STEP 3: Hasil =====
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
}

const _feedbackReasons = <String>[
  'General Feedback',
  'Inappropriate Content',
  'Misleading Information',
  'Bug / Technical Issue',
];

/// Badge countdown mandiri: timer & setState-nya lokal, jadi tidak me-rebuild
/// seluruh layar runner setiap detik. Panggil [onExpired] sekali saat habis.
class _CountdownBadge extends StatefulWidget {
  final int minutes;
  final VoidCallback onExpired;

  const _CountdownBadge({required this.minutes, required this.onExpired});

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
    _secondsLeft = widget.minutes * 60;
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
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
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

/// Bottom sheet kirim feedback setelah mengerjakan form (user login).
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
