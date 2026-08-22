import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/router/app_router.dart';

/// Detail riwayat satu form: info lengkap form + daftar attempt pengerjaan
class HistoryFormDetailScreen extends StatefulWidget {
  final String formLink;
  final String formTitle;

  const HistoryFormDetailScreen({
    super.key,
    required this.formLink,
    this.formTitle = '',
  });

  @override
  State<HistoryFormDetailScreen> createState() =>
      _HistoryFormDetailScreenState();
}

class _HistoryFormDetailScreenState extends State<HistoryFormDetailScreen> {
  bool _loading = true;
  PublicFormInfo? _info;
  List<MyAttempt> _attempts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final attempts = await PublicFormService.getMyAttempts(widget.formLink);
      // Info form bisa gagal (mis. form sudah tidak published) — attempts
      // tetap ditampilkan agar riwayat tidak hilang.
      PublicFormInfo? info;
      try {
        info = await PublicFormService.getFormInfo(widget.formLink);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _info = info;
        _attempts = attempts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xCCBDC9C8)),
        ),
        title: const Text(
          "Riwayat Form",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AuthBackground(
              child: SafeArea(
                child: RefreshIndicator(
                  color: kAuthPrimary,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 16),
                      Text(
                        "Riwayat Pengerjaan (${_attempts.length})",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_attempts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            "Belum ada riwayat pengerjaan.",
                            style: TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        )
                      else
                        for (var i = 0; i < _attempts.length; i++) ...[
                          _AttemptCard(
                            index: i,
                            attempt: _attempts[i],
                            onTap: () => AppRouter.of(context).push(
                              AppPage.formHistoryDetail,
                              {
                                'formLink': widget.formLink,
                                'responseId': _attempts[i].responseId,
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    final title = _info?.title ?? widget.formTitle;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((_info?.bannerImage ?? '').isNotEmpty)
            AspectRatio(
              aspectRatio: 3,
              child: Image.network(
                _resolveUrl(_info!.bannerImage!),
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichTextView(
                  text: title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
                if (_info?.description != null &&
                    _info!.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  RichTextView(
                    text: _info!.description!,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 14),
                _infoRow(Icons.quiz_outlined,
                    "${_info?.questionCount ?? '-'} soal"),
                _infoRow(Icons.category_outlined, _formTypeLabel()),
                if (_info?.timerDuration != null)
                  _infoRow(Icons.timer_outlined,
                      "${_info!.timerDuration} menit"),
                _infoRow(Icons.login_outlined,
                    _formatDateTime(_info?.openFormTime) ?? "Langsung terbuka"),
                _infoRow(Icons.logout_outlined,
                    _formatDateTime(_info?.closeFormTime) ??
                        "Tidak ada batas tutup"),
                if (_info?.showScore == true)
                  _infoRow(
                      Icons.leaderboard_outlined, "Menampilkan nilai"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formTypeLabel() {
    switch (_info?.formTypeId) {
      case 2:
        return "Ujian";
      case 1:
        return "Formulir";
      default:
        return "Tidak diketahui";
    }
  }

  String? _formatDateTime(DateTime? dt) {
    if (dt == null) return null;
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return "${local.day}/${local.month}/${local.year} $hh:$mm";
  }

  String _resolveUrl(String path) {
    if (path.startsWith('http')) return path;
    final base = apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return '$base$path';
  }
}

Widget _infoRow(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 16, color: kAuthPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    ),
  );
}

/// Kartu satu attempt: nomor, tanggal pengerjaan, dan skor bila ditampilkan
class _AttemptCard extends StatelessWidget {
  final int index;
  final MyAttempt attempt;
  final VoidCallback onTap;

  const _AttemptCard({
    required this.index,
    required this.attempt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dt = attempt.submittedAt?.toLocal();
    final dateText = dt == null
        ? "Waktu tidak diketahui"
        : "${dt.day}/${dt.month}/${dt.year} "
            "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kPrimarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "#${index + 1}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: kAuthPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Percobaan",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateText,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              if (attempt.showScore && attempt.score != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: attempt.score! >= 75
                        ? const Color(0xFFE3F4E8)
                        : attempt.score! >= 50
                            ? const Color(0xFFFFF3E0)
                            : const Color(0xFFFDECEA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${attempt.score!.toStringAsFixed(1)}%",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: attempt.score! >= 75
                          ? const Color(0xFF2E7D32)
                          : attempt.score! >= 50
                              ? const Color(0xFFB26A00)
                              : const Color(0xFFC0392B),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
