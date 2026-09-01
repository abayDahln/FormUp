import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/features/form_runner/controllers/runner_answer_store.dart';

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

enum _HistorySort { newest, oldest, highScore, lowScore }

extension _HistSortExt on _HistorySort {
  String get label => switch (this) {
        _HistorySort.newest => 'Terbaru',
        _HistorySort.oldest => 'Terlama',
        _HistorySort.highScore => 'Nilai tertinggi',
        _HistorySort.lowScore => 'Nilai terendah',
      };
  IconData get icon => switch (this) {
        _HistorySort.newest => Icons.schedule_outlined,
        _HistorySort.oldest => Icons.history_outlined,
        _HistorySort.highScore => Icons.arrow_upward_outlined,
        _HistorySort.lowScore => Icons.arrow_downward_outlined,
      };
}

class _HistoryFormDetailScreenState extends State<HistoryFormDetailScreen> {
  bool _loading = true;
  PublicFormInfo? _info;
  List<MyAttempt> _attempts = [];
  _HistorySort _sort = _HistorySort.newest;

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
      attempts.sort((a, b) {
        final da = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return da.compareTo(db);
      });
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
      backgroundColor: kAppBg,
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
          ? const AppLoadingOverlay()
          : AuthBackground(plain: true,
              child: SafeArea(
                child: AppRefreshIndicator(
                  indicatorColor: kAuthPrimary,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            "Riwayat Pengerjaan (${_attempts.length})",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: kFontBold,
                              color: Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          MenuAnchor(
                            builder: (context, controller, child) => IconButton(
                              icon: Icon(Icons.tune, color: _sort == _HistorySort.newest ? Colors.black54 : kAuthPrimary, size: 20),
                              tooltip: 'Filter & urutkan',
                              style: IconButton.styleFrom(
                                backgroundColor: _sort == _HistorySort.newest ? Colors.transparent : const Color(0xFFE2F3F2),
                              ),
                              onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                            ),
                            menuChildren: [
                              for (final s in _HistorySort.values)
                                MenuItemButton(
                                  leadingIcon: Icon(s.icon, size: 18, color: _sort == s ? kAuthPrimary : Colors.black54),
                                  onPressed: () => setState(() => _sort = s),
                                  child: Text(s.label, style: TextStyle(fontSize: 14, color: _sort == s ? kAuthPrimary : Colors.black87, fontWeight: _sort == s ? FontWeight.bold : FontWeight.normal)),
                                ),
                            ],
                          ),
                        ],
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
                        Builder(builder: (context) {
                          final sorted = _sortedAttempts;
                          // Map kronologis: #1 = paling lama (sesuai Komentar di PublicFormService.getMyAttempts)
                          final chrono = List<MyAttempt>.from(_attempts)
                            ..sort((a, b) {
                              final da = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                              final db = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                              return da.compareTo(db);
                            });
                          final numberById = {
                            for (var j = 0; j < chrono.length; j++) chrono[j].responseId: j + 1,
                          };
                          return Column(
                            children: [
                              for (var i = 0; i < sorted.length; i++) ...[
                                _AttemptCard(
                                  key: ValueKey(sorted[i].responseId),
                                  index: (numberById[sorted[i].responseId] ?? i + 1) - 1,
                                  attempt: sorted[i],
                                  onTap: () => AppRouter.of(context).push(
                                    AppPage.formHistoryDetail,
                                    {
                                      'formLink': widget.formLink,
                                      'responseId': sorted[i].responseId,
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          );
                        }),
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
              child: CachedRemoteImage(
                url: _resolveUrl(_info!.bannerImage!),
                fit: BoxFit.cover,
                errorWidget: const SizedBox.shrink(),
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
                      formatRunnerDuration(_info!.timerDuration!)),
                if (_info?.openFormTime != null)
                  _infoRow(Icons.login_outlined,
                      _formatDateTime(_info!.openFormTime)!),
                if (_info?.closeFormTime != null)
                  _infoRow(Icons.logout_outlined,
                      _formatDateTime(_info!.closeFormTime)!),
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

  List<MyAttempt> get _sortedAttempts {
    final list = List<MyAttempt>.from(_attempts);
    switch (_sort) {
      case _HistorySort.newest:
        list.sort((a, b) {
          final da = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
        break;
      case _HistorySort.oldest:
        list.sort((a, b) {
          final da = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return da.compareTo(db);
        });
        break;
      case _HistorySort.highScore:
        list.sort((a, b) => (b.score ?? -1).compareTo(a.score ?? -1));
        break;
      case _HistorySort.lowScore:
        list.sort((a, b) => (a.score ?? 999).compareTo(b.score ?? 999));
        break;
    }
    return list;
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
    super.key,
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
                    Text(
                      "Percobaan ke-${index + 1}",
                      style: const TextStyle(
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
