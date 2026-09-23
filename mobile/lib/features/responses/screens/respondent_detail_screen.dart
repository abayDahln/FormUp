import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/connection_error_view.dart';
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
  String? _loadError;
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
    setState(() {
      _loading = true;
      _loadError = null;
    });
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
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_result == null && AuthService.isConnectionError(e)) {
        setState(() => _loadError = AuthService.errorMessage(e));
        return;
      }
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
          : _loadError != null && _result == null
              ? Center(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: ConnectionErrorView(
                      message: _loadError!,
                      onRetry: () => _load(refresh: true),
                    ),
                  ),
                )
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

  /// Pemilih attempt: dropdown ringkas (hemat tempat) — trigger menampilkan
  /// percobaan aktif, mis. "Percobaan 1 (2/9/2026 - Skor 0.0)".
  /// Diketuk → bottom sheet (phone) / dialog (desktop) berisi daftar seluruh
  /// percobaan dari yang terbaru ke terlama. Percobaan terbaru otomatis
  /// terpilih saat screen dibuka (urutan server: terbaru dulu).
  Widget _buildAttemptSelector() {
    final cs = Theme.of(context).colorScheme;
    var selectedIndex = _attempts.indexWhere(
      (a) => a.responseId == _selectedResponseId,
    );
    if (selectedIndex < 0) selectedIndex = 0;
    final selected = _attempts[selectedIndex];
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _showAttemptPicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: softShadow(),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history,
                  size: 18,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _attemptTitle(selected, selectedIndex),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _attemptSubtitle(selected),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedIndex == 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Terbaru',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: cs.primary,
                    ),
                  ),
                ),
              Icon(
                Icons.expand_more,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Judul attempt: "Percobaan N" (N = 1 untuk yang terbaru).
  String _attemptTitle(MyAttempt attempt, int index) =>
      'Percobaan ${index + 1}';

  /// Subjudul attempt: "2/9/2026 14:30 - Skor 0.0" (skor hanya bila dinilai).
  String _attemptSubtitle(MyAttempt attempt) {
    final parts = <String>[];
    final dt = attempt.submittedAt?.toLocal();
    if (dt == null) {
      parts.add('Waktu tidak diketahui');
    } else {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      parts.add('${dt.day}/${dt.month}/${dt.year} $hh:$mm');
    }
    if (attempt.showScore) {
      parts.add(
        'Skor ${attempt.score?.toStringAsFixed(1) ?? '—'}',
      );
    }
    return parts.join(' - ');
  }

  Future<void> _showAttemptPicker() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await AdaptiveSheet.show<int>(
      context: context,
      isScrollControlled: true,
      // Konten scroll sendiri via DraggableScrollableSheet — pola yang sama
      // seperti UserGuideSheet sehingga aman di phone maupun dialog
      // tablet/desktop (Windows): tinggi selalu terbatas, tak ada
      // Flexible/Expanded di dalam area tak terbatas.
      selfScrolling: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx, _) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, controller) => SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pilih Percobaan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  fontSize: 15,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_attempts.length} pengerjaan • terbaru ke terlama',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: _attempts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final attempt = _attempts[i];
                  final isSelected =
                      attempt.responseId == _selectedResponseId;
                  return ListTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primary
                            : cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: kFontBold,
                            color: isSelected
                                ? cs.onPrimary
                                : cs.primary,
                          ),
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          _attemptTitle(attempt, i),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: kFontBold,
                            fontSize: 13,
                            color: cs.onSurface,
                          ),
                        ),
                        if (i == 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Terbaru',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: kFontBold,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      _attemptSubtitle(attempt),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: cs.primary)
                        : Icon(
                            Icons.chevron_right,
                            color: cs.outline,
                          ),
                    onTap: () => Navigator.pop(ctx, attempt.responseId),
                  );
                },
              ),
            ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) _selectAttempt(picked);
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