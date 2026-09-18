import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/features/form/widgets/history_answer_card.dart';

/// Detail jawaban lengkap satu responden untuk sebuah form.
/// Default menampilkan respon TERBARU; responden yang mengerjakan lebih
/// dari sekali bisa memilih attempt lain berdasarkan waktu pengerjaan.
class RespondentDetailScreen extends StatefulWidget {
  final int formId;
  final String title;
  final int responseId;
  final String respondentName;

  const RespondentDetailScreen({
    super.key,
    required this.formId,
    required this.responseId,
    this.title = '',
    this.respondentName = '',
  });

  @override
  State<RespondentDetailScreen> createState() => _RespondentDetailScreenState();
}

class _RespondentDetailScreenState extends State<RespondentDetailScreen> {
  bool _loading = true;
  PublicFormResult? _result;
  List<MyAttempt> _attempts = [];
  late int _selectedResponseId;
  bool _oneResponse = false;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _selectedResponseId = widget.responseId;
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        FormService.getResponseResult(widget.formId, _selectedResponseId, refresh: refresh),
        FormService.getRespondentAttempts(widget.formId, widget.responseId, refresh: refresh),
        FormService.getForm(widget.formId, refresh: refresh),
      ]);
      if (!mounted) return;
      final formMap = results[2] as Map<String, dynamic>;
      final settings = formMap['settings'] as Map<String, dynamic>?;
      setState(() {
        _result = results[0] as PublicFormResult;
        _attempts = results[1] as List<MyAttempt>;
        _oneResponse = settings?['oneResponse'] as bool? ?? false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  Future<void> _selectAttempt(int responseId) async {
    if (responseId == _selectedResponseId) return;
    setState(() {
      _selectedResponseId = responseId;
      _loading = true;
    });
    try {
      final result =
          await FormService.getResponseResult(widget.formId, responseId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  /// canReset untuk respons yang sedang ditampilkan (false bila attempts
  /// belum dimuat — tombol disembunyikan sampai data siap).
  bool get _selectedCanReset {
    for (final a in _attempts) {
      if (a.responseId == _selectedResponseId) return a.canReset;
    }
    return false;
  }

  /// Reset pengerjaan ulang untuk respons yang sedang ditampilkan.
  /// Server menjaga riwayat + memberi 1 jatah isi ulang (sesi baru).
  Future<void> _confirmReset() async {
    final displayName = widget.respondentName.trim().isNotEmpty
        ? widget.respondentName.trim()
        : 'Responden';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Jawaban Peserta?'),
        content: Text(
          'Data lama milik "$displayName" dipertahankan sebagai riwayat dan '
          'peserta diberi 1 jatah isi ulang untuk mengerjakan kembali. '
          'Reset hanya bisa dipakai sekali untuk upaya ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _resetting = true);
    try {
      final msg = await FormService.resetFormResponse(
          widget.formId, _selectedResponseId);
      if (!mounted) return;
      showAuthToast(context, msg);
      await _load(refresh: true);
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = widget.respondentName.trim().isNotEmpty
        ? widget.respondentName.trim()
        : 'Responden';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape:  Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
        leading: IconButton(
          icon:  Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:  TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
          ),
        ),
        actions: [
          // Reset pengerjaan ulang (khusus form one-response): respons lama
          // dipertahankan sebagai riwayat, responden diberi 1 jatah isi ulang.
          // Sekali klik per upaya: hanya upaya terbaru yang jatahnya belum
          // dipakai (canReset dari server) yang menampilkan tombol.
          if (_oneResponse && _selectedCanReset)
            IconButton(
              tooltip: 'Reset agar responden dapat mengerjakan kembali',
              onPressed: _resetting ? null : _confirmReset,
              icon: _resetting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : Icon(Icons.restart_alt, color: cs.onSurface),
            ),
        ],
      ),
      body: _loading && _result == null
          ? const AppLoadingOverlay()
          : AuthBackground(plain: true,
              child: SafeArea(
                child: AppRefreshIndicator(
                  onRefresh: () => _load(refresh: true),
                  child: ListView(
                    padding: centerPad(context, base: const EdgeInsets.fromLTRB(20, 16, 20, 24), wideMaxWidth: 1000),
                  children: [
                    if (_attempts.length > 1) ...[
                      _buildAttemptSelector(),
                      const SizedBox(height: 16),
                    ],
                    if (!isDesktopWidth(context)) ...[
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _answersTitle(cs),
                      const SizedBox(height: 12),
                      _answersList(),
                      // Desktop: ringkasan 360 kiri + jawaban kanan.
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 360,
                            child: _buildSummaryCard(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _answersTitle(cs),
                                const SizedBox(height: 12),
                                _answersList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                ),
              ),
            ),
    );
  }

  Widget _answersTitle(ColorScheme cs) {
    return Text(
      _result?.showScore == true ? "Pembahasan Jawaban" : "Jawaban Responden",
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        fontFamily: kFontBold,
        color: cs.onSurface,
      ),
    );
  }

  Widget _answersList() {
    if (_result == null || _result!.answers.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          "Belum ada jawaban.",
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _result!.answers.length; i++) ...[
          HistoryAnswerCard(
            index: i,
            answer: _result!.answers[i],
            showScore: _result!.showScore,
            responseId: _selectedResponseId,
            formId: widget.formId,
            onScoreUpdated: _load,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  /// Pemilih attempt: chip horizontal dibedakan berdasarkan waktu pengerjaan.
  /// Percobaan terbaru otomatis terpilih saat screen dibuka.
  Widget _buildAttemptSelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _attempts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final attempt = _attempts[i];
          final selected = attempt.responseId == _selectedResponseId;
          final dt = attempt.submittedAt?.toLocal();
          final label = dt == null
              ? "Percobaan ${i + 1}"
              : "Percobaan ${i + 1} · "
                  "${dt.day}/${dt.month}/${dt.year} "
                  "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _selectAttempt(attempt.responseId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  fontFamily: selected ? kFontBold : null,
                  color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard() {
    final result = _result;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichTextView(
            text: widget.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:  TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _submittedText(),
            style:  TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCell("${result.answeredCount}/${result.totalQuestions}",
                    "Dijawab"),
                if (result.showScore)
                  _StatCell(result.score?.toStringAsFixed(1) ?? "—", "Skor"),
                if (result.showScore)
                  _StatCell("${result.correctCount}", "Benar",
                      color: const Color(0xFF2E7D32)),
                if (result.showScore)
                  _StatCell("${result.wrongCount}", "Salah",
                      color: const Color(0xFFC0392B)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _submittedText() {
    // Waktu attempt aktif diambil dari daftar attempt kalau tersedia.
    for (final a in _attempts) {
      if (a.responseId == _selectedResponseId && a.submittedAt != null) {
        final dt = a.submittedAt!.toLocal();
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        return "Dikerjakan ${dt.day}/${dt.month}/${dt.year} $hh:$mm";
      }
    }
    return "";
  }
}

/// Satu sel statistik pada kartu ringkasan
class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const _StatCell(this.value, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: color ?? cs.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style:  TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }
}