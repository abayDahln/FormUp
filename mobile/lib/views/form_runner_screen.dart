import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import '../services/auth_service.dart';
import '../services/public_form_service.dart';
import '../app_router.dart';

/// Alur: masukkan kode → (token jika wajib) → isi jawaban → lihat hasil.
class FormRunnerScreen extends StatefulWidget {
  final String? initialCode;

  const FormRunnerScreen({super.key, this.initialCode});

  @override
  State<FormRunnerScreen> createState() => _FormRunnerScreenState();
}

enum _RunnerStep { code, fill, result }

class _FormRunnerScreenState extends State<FormRunnerScreen> {
  final _codeController = TextEditingController();
  final _tokenController = TextEditingController();
  final _nameController = TextEditingController();

  _RunnerStep _step = _RunnerStep.code;
  bool _loading = false;
  bool _submitting = false;

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
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      showAuthToast(context, "Masukkan kode form terlebih dahulu", isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final info = await PublicFormService.getFormInfo(code);
      if (!mounted) return;
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

  Future<void> _submit() async {
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
      final guestToken = await PublicFormService.getGuestToken();
      final data = await PublicFormService.submit(
        _formLink!,
        token: _tokenController.text.trim().isEmpty
            ? null
            : _tokenController.text.trim(),
        respondentName: _isLoggedIn ? null : _nameController.text,
        guestToken: guestToken,
        answers: answers,
      );
      final responseId = data['responseId'] as int;
      final result = await PublicFormService.getResult(
        _formLink!,
        responseId,
        guestToken: guestToken,
      );
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
      _tokenController.clear();
      _nameController.clear();
    });
  }

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
        title: Text(
          switch (_step) {
            _RunnerStep.code => "Kerjakan Form",
            _RunnerStep.fill => _info?.title ?? "Kerjakan Form",
            _RunnerStep.result => "Hasil",
          },
          style: const TextStyle(fontFamily: kFontBold, color: Colors.black87),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AuthBackground(
              child: SafeArea(
                child: switch (_step) {
                  _RunnerStep.code => _buildCodeStep(),
                  _RunnerStep.fill => _buildFillStep(),
                  _RunnerStep.result => _buildResultStep(),
                },
              ),
            ),
    );
  }

  // ===== STEP 1: Input kode + token =====
  Widget _buildCodeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthTitle(
            title: "Kerjakan Form",
            subtitle: "Masukkan kode form dari pemilik untuk mulai mengerjakan.",
          ),
          const SizedBox(height: 32),
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
                Text(
                  info.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
                if (info.description != null && info.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    info.description!,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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
    final info = _info!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: softShadow(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
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
              ),
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
                child: Text(
                  q.question,
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
          _buildAnswerField(q),
        ],
      ),
    );
  }

  Widget _buildAnswerField(PublicQuestion q) {
    switch (q.typeId) {
      case 1: // Essay
        return TextField(
          controller: _textAnswers[q.id],
          maxLines: 3,
          decoration: _answerDecoration("Tulis jawaban Anda..."),
        );
      case 2: // Multiple Choice
        return RadioGroup<int>(
          groupValue: _singleAnswers[q.id],
          onChanged: (v) => setState(() => _singleAnswers[q.id] = v),
          child: Column(
            children: [
              for (final o in q.options)
                RadioListTile<int>(
                  value: o.id,
                  title: Text(o.optionText,
                      style: const TextStyle(fontSize: 14)),
                  dense: true,
                  activeColor: kAuthPrimary,
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        );
      case 3: // Checkbox
        return Column(
          children: [
            for (final o in q.options)
              CheckboxListTile(
                value: (_multiAnswers[q.id] ?? {}).contains(o.id),
                onChanged: (v) {
                  setState(() {
                    final selected = _multiAnswers[q.id] ?? {};
                    if (v == true) {
                      selected.add(o.id);
                    } else {
                      selected.remove(o.id);
                    }
                    _multiAnswers[q.id] = selected;
                  });
                },
                title: Text(o.optionText, style: const TextStyle(fontSize: 14)),
                dense: true,
                activeColor: kAuthPrimary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
          ],
        );
      case 4: // Date Time
        final dt = _datetimeAnswers[q.id];
        return InkWell(
          onTap: () => _pickDateTime(q.id),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6E7979)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 18, color: kAuthPrimary),
                const SizedBox(width: 10),
                Text(
                  dt == null
                      ? "Pilih tanggal & waktu"
                      : _formatDateTime(dt),
                  style: TextStyle(
                    fontSize: 14,
                    color: dt == null ? Colors.black45 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      case 5: // True/False
        return Row(
          children: [
            Expanded(
              child: _answerChip(
                "Benar",
                _tfAnswers[q.id] == 'Benar',
                () => setState(() => _tfAnswers[q.id] = 'Benar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _answerChip(
                "Salah",
                _tfAnswers[q.id] == 'Salah',
                () => setState(() => _tfAnswers[q.id] = 'Salah'),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _answerChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kPrimarySoft : const Color(0xFFF0F4F4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kAuthPrimary : const Color(0xFF6E7979),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: selected ? kAuthPrimary : Colors.black54,
          ),
        ),
      ),
    );
  }

  InputDecoration _answerDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kAuthText, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF0F4F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF6E7979)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF6E7979)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kAuthPrimary, width: 1.5),
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
        ],
      ),
    );
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
                child: Text(
                  "${index + 1}. ${a.question}",
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
                Text(
                  answered ? a.answerText! : "Tidak dijawab",
                  style: TextStyle(
                    fontSize: 14,
                    color: answered ? Colors.black87 : Colors.black45,
                    fontStyle: answered ? FontStyle.normal : FontStyle.italic,
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
                  Text(
                    a.correctAnswer!,
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
