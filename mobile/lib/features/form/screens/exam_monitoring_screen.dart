import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/search_field.dart';

/// Pantauan LIVE mode ujian untuk owner — setara tab monitoring di web:
/// - Polling tiap 15 detik + indikator LIVE berdenyut.
/// - Ringkasan: mode ujian, sedang mengerjakan, online saat ini, terkumpul.
/// - Filter (semua/mengerjakan/terkumpul/berpelanggaran/tinggi) + pencarian.
/// - Kartu peserta: status online, jumlah pelanggaran, ditandai merah bila
///   melampaui batas, log pelanggaran yang bisa dibuka per peserta.
class ExamMonitoringScreen extends StatefulWidget {
  final int formId;
  final String title;

  const ExamMonitoringScreen({
    super.key,
    required this.formId,
    this.title = '',
  });

  @override
  State<ExamMonitoringScreen> createState() => _ExamMonitoringScreenState();
}

class _ExamMonitoringScreenState extends State<ExamMonitoringScreen>
    with SingleTickerProviderStateMixin {
  ExamMonitoringData? _data;
  bool _loading = true;
  DateTime? _lastUpdated;
  Timer? _poller;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.4,
    upperBound: 1,
  )..repeat(reverse: true);

  String _filter = 'all';
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
    _poller = Timer.periodic(
        const Duration(seconds: 5), (_) => _fetch(silent: true));
  }

  @override
  void dispose() {
    _poller?.cancel();
    _pulse.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await FormService.getExamMonitoring(widget.formId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent) {
        showAuthToast(context, AuthService.errorMessage(e), isError: true);
      }
    }
  }

  List<ExamMonitoringSession> _filtered(ExamMonitoringData data) {
    final maxSw = data.maxTabSwitch ?? 3;
    final q = _search.trim().toLowerCase();
    return data.sessions.where((s) {
      final name = (s.respondentName ?? '').toLowerCase();
      if (q.isNotEmpty && !name.contains(q)) return false;
      switch (_filter) {
        case 'in_progress':
          return s.status == 'in_progress';
        case 'submitted':
          return s.status == 'submitted';
        case 'violations':
          return s.violationCount > 0;
        case 'high_violations':
          return s.violationCount >= maxSw || s.tabSwitchCount >= maxSw;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: cs.outlineVariant)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => AppRouter.of(context).pop(),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.title.isEmpty ? 'Pantau Ujian' : 'Pantau: ${widget.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Badge LIVE berdenyut + waktu pembaruan terakhir.
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _pulse,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: cs.onTertiaryContainer,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: kFontBold,
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: cs.onSurface),
            tooltip: 'Muat ulang',
            onPressed: () => _fetch(),
          ),
        ],
      ),
      body: _loading && data == null
          ? const AppLoadingOverlay()
          : AppRefreshIndicator(
              onRefresh: () => _fetch(silent: true),
              indicatorColor: cs.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (data != null) ...[
                    _SummaryGrid(data: data),
                    const SizedBox(height: 12),
                    _FilterBar(
                      data: data,
                      filter: _filter,
                      searchController: _searchController,
                      onFilter: (f) => setState(() => _filter = f),
                      onSearch: (s) => setState(() => _search = s),
                    ),
                    const SizedBox(height: 12),
                    if (_lastUpdated != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Diperbarui '
                              '${_lastUpdated!.toLocal().toString().substring(11, 16)}'
                              ' • diperbarui otomatis tiap 15 detik',
                          style:  TextStyle(
                              fontSize: 10.5, color: cs.onSurfaceVariant),
                        ),
                      ),
                    ..._sessionList(data),
                  ] else
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Memuat data...')),
                    ),
                ],
              ),
            ),
    );

  }

  List<Widget> _sessionList(ExamMonitoringData data) {
    final cs = Theme.of(context).colorScheme;
    final sessions = _filtered(data);
    if (sessions.isEmpty) {
      return [
        Card(
          elevation: 0,
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant),
          ),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.shield_outlined, size: 34, color: cs.onSurfaceVariant),
                const SizedBox(height: 10),
                const Text(
                  'Belum ada peserta ujian ditemukan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: kFontBold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Peserta yang membuka halaman ujian otomatis tercatat dan '
                  'muncul di sini secara real-time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      for (final s in sessions) ...[
        _SessionCard(session: s, maxTabSwitch: data.maxTabSwitch ?? 3, formId: widget.formId, onChanged: () => _fetch(silent: true)),
        const SizedBox(height: 10),
      ],
    ];
  }
}

// ---------------------------------------------------------------------------
// Ringkasan 2x2
// ---------------------------------------------------------------------------

class _SummaryGrid extends StatelessWidget {
  final ExamMonitoringData data;

  const _SummaryGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final examActive = data.isExamMode == true || data.detectTabSwitch == true;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Mode Ujian',
                value: examActive ? 'Aktif' : 'Nonaktif',
                icon: Icons.shield_outlined,
                iconColor: examActive ? cs.primary : cs.onSurfaceVariant,
                valueColor: examActive ? cs.primary : cs.onSurfaceVariant,
                subtitle: data.autoSubmitOnTabSwitch == true
                    ? 'Auto-submit maks ${data.maxTabSwitch ?? 3}x pindah tab'
                    : (examActive ? 'Pencatatan pelanggaran aktif' : 'Belum aktif'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Online',
                value: '${data.onlineCount}',
                icon: Icons.wifi_rounded,
                iconColor: cs.tertiary,
                valueColor: cs.tertiary,
                subtitle: 'Aktif 90 detik terakhir',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Mengerjakan',
                value: '${data.inProgressCount}',
                icon: Icons.edit_note_outlined,
                iconColor: cs.secondary,
                valueColor: cs.secondary,
                subtitle: 'Belum mengirim jawaban',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Terkumpul',
                value: '${data.submittedCount}',
                icon: Icons.check_circle_outline,
                iconColor: cs.primary,
                valueColor: cs.primary,
                subtitle: 'Jawaban tersimpan',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color valueColor;
  final String subtitle;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.valueColor,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: kFontBold,
                      letterSpacing: 0.6,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(icon, size: 16, color: iconColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontFamily: kFontBold,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chips + pencarian
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  final ExamMonitoringData data;
  final String filter;
  final TextEditingController searchController;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSearch;

  const _FilterBar({
    required this.data,
    required this.filter,
    required this.searchController,
    required this.onFilter,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const filters = [
      ('all', 'Semua', Icons.apps_outlined),
      ('in_progress', 'Mengerjakan', Icons.edit_note_outlined),
      ('submitted', 'Terkumpul', Icons.check_circle_outline),
      ('violations', 'Berpelanggaran', Icons.flag_outlined),
      ('high_violations', 'Bahaya', Icons.warning_amber_outlined),
    ];
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (id, label, icon) in filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 15),
                            const SizedBox(width: 5),
                            Text(label),
                          ],
                        ),
                        selected: filter == id,
                        onSelected: (_) => onFilter(id),
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        showCheckmark: false,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppSearchField(
              controller: searchController,
              onChanged: onSearch,
              hint: 'Cari nama peserta...',
              historyKey: 'search_history_exam_monitoring',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu peserta
// ---------------------------------------------------------------------------

/// Label Indonesia untuk tipe pelanggaran.
String _violationLabel(String type) {
  switch (type) {
    case 'tab_switch':
      return 'Pindah tab / aplikasi';
    case 'window_blur':
      return 'Keluar jendela';
    case 'copy_attempt':
      return 'Mencoba menyalin';
    case 'paste_attempt':
      return 'Mencoba menempel';
    case 'context_menu':
      return 'Klik kanan';
    default:
      return type;
  }
}

String _relativeTime(DateTime? time) {
  if (time == null) return '-';
  final d = DateTime.now().toUtc().difference(time.toUtc());
  if (d.inSeconds < 60) return 'baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} mnt lalu';
  if (d.inHours < 24) return '${d.inHours} jam lalu';
  return '${d.inDays} hari lalu';
}

String _clockTime(DateTime? time) {
  if (time == null) return '-';
  final t = time.toLocal();
  return t.toString().substring(11, 16);
}

class _SessionCard extends StatefulWidget {
  final ExamMonitoringSession session;
  final int maxTabSwitch;
  final int formId;
  final VoidCallback? onChanged;

  const _SessionCard({required this.session, required this.maxTabSwitch, required this.formId, this.onChanged});

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = false;
  bool _acting = false;

  ExamMonitoringSession get s => widget.session;
  bool get _high =>
      s.violationCount >= widget.maxTabSwitch ||
      s.tabSwitchCount >= widget.maxTabSwitch;
  bool get _submitted => s.status == 'submitted';

  Future<void> _forceSubmit() async {
    final id = s.sessionId;
    if (id == null || id.isEmpty || _acting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paksa submit?'),
        content: Text('Paksa kumpulkan jawaban ${s.respondentName ?? 'peserta'} apa adanya?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, submit')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _acting = true);
    try {
      await FormService.forceSubmitExamSession(widget.formId, id);
      widget.onChanged?.call();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Peserta di-submit paksa')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reset() async {
    final id = s.sessionId;
    if (id == null || id.isEmpty || _acting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset sesi?'),
        content: const Text('Keluarkan peserta dan reset progres ke 0? Peserta harus mengulang dari awal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, reset')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _acting = true);
    try {
      await FormService.resetExamSession(widget.formId, id);
      widget.onChanged?.call();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesi peserta di-reset')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = (s.respondentName?.isNotEmpty ?? false)
        ? s.respondentName!
        : 'Anonim';
    final hasViolations = s.violationCount > 0;
    // Warna status tonal sesuai scheme (aman terang/gelap).
    final statusBg = _submitted
        ? cs.surfaceContainerHighest
        : (s.isOnline ? cs.tertiaryContainer : cs.secondaryContainer);
    final statusFg = _submitted
        ? cs.onSurfaceVariant
        : (s.isOnline ? cs.onTertiaryContainer : cs.onSecondaryContainer);
    final statusLabel =
        _submitted ? 'Terkumpul' : (s.isOnline ? 'Online' : 'Offline');
    final dotColor = _submitted
        ? cs.outline
        : (s.isOnline ? cs.tertiary : cs.outline);
    final progress = s.totalQuestions > 0
        ? (s.answeredCount / s.totalQuestions).clamp(0.0, 1.0)
        : 0.0;
    return Card(
      elevation: 0,
      color: _high ? cs.errorContainer.withValues(alpha: 0.35) : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _high ? cs.error : cs.outlineVariant,
          width: _high ? 1.5 : 1,
        ),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: hasViolations ? () => setState(() => _expanded = !_expanded) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar + titik status online.
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          name.characters.first.toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: kFontBold,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.surface, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFamily: kFontBold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _submitted
                              ? 'Terkumpul ${_relativeTime(s.submittedAt ?? s.lastSeenAt)}'
                              : (s.isOnline
                                  ? 'Aktivitas ${_relativeTime(s.lastSeenAt)}'
                                  : 'Terakhir aktif ${_relativeTime(s.lastSeenAt)}'),
                          style: TextStyle(
                              fontSize: 11.5, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: kFontBold,
                        color: statusFg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progres jawaban.
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.totalQuestions > 0
                        ? '${s.answeredCount}/${s.totalQuestions}'
                        : '${s.answeredCount}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: kFontBold,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Ringkasan pelanggaran.
              Row(
                children: [
                  Expanded(
                    child: _violationStat(
                      context,
                      'Pelanggaran',
                      '${s.violationCount}',
                      s.violationCount > 0 ? cs.error : cs.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: _violationStat(
                      context,
                      'Pindah tab',
                      '${s.tabSwitchCount}',
                      s.tabSwitchCount > 0 ? cs.error : cs.onSurfaceVariant,
                    ),
                  ),
                  if (hasViolations)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: _expanded ? 'Sembunyikan' : 'Lihat log',
                      onPressed: () =>
                          setState(() => _expanded = !_expanded),
                      icon: AnimatedRotation(
                        turns: _expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(Icons.chevron_right,
                            size: 20, color: cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
              if (_high)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 15, color: cs.onErrorContainer),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pelanggaran tinggi (batas ${widget.maxTabSwitch}x)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: kFontBold,
                              color: cs.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Log pelanggaran (expand).
              if (_expanded && hasViolations) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final v in s.violations)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(Icons.flag_rounded,
                                  size: 13, color: cs.error),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _violationLabel(v.type),
                                  style: TextStyle(
                                      fontSize: 12, color: cs.onSurface),
                                ),
                              ),
                              Text(
                                _clockTime(v.occurredAt),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              // Kontrol owner: paksa submit / reset sesi (hanya sesi aktif).
              if (!_submitted && s.sessionId != null && s.sessionId!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _acting ? null : _forceSubmit,
                        icon: const Icon(Icons.upload_rounded, size: 16),
                        label: const Text('Paksa submit',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                fontFamily: kFontBold)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _acting ? null : _reset,
                        icon: const Icon(Icons.restart_alt_rounded, size: 16),
                        label: const Text('Reset sesi',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                fontFamily: kFontBold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _violationStat(BuildContext context, String label, String value, Color color) => Row(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: kFontBold,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      );
}
