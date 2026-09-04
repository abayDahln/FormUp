import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

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

  @override
  void initState() {
    super.initState();
    _fetch();
    _poller = Timer.periodic(
        const Duration(seconds: 15), (_) => _fetch(silent: true));
  }

  @override
  void dispose() {
    _poller?.cancel();
    _pulse.dispose();
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
    final data = _data;
    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xCCBDC9C8))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
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
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black87,
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
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.green.shade200),
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
                          color: Colors.green.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () => _fetch(),
          ),
        ],
      ),
      body: _loading && data == null
          ? const AppLoadingOverlay()
          : RefreshIndicator(
              onRefresh: () => _fetch(silent: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (data != null) ...[
                    _SummaryGrid(data: data),
                    const SizedBox(height: 12),
                    _FilterBar(
                      data: data,
                      filter: _filter,
                      search: _search,
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
                          style: const TextStyle(
                              fontSize: 10.5, color: Colors.black45),
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
    final sessions = _filtered(data);
    if (sessions.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(),
          child: const Column(
            children: [
              Icon(Icons.shield_outlined, size: 34, color: Colors.black26),
              SizedBox(height: 8),
              Text(
                'Belum ada peserta ujian ditemukan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'Peserta yang membuka halaman ujian otomatis tercatat dan '
                'muncul di sini secara real-time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.black45),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      for (final s in sessions) ...[
        _SessionCard(session: s, maxTabSwitch: data.maxTabSwitch ?? 3),
        const SizedBox(height: 10),
      ],
    ];
  }

  BoxDecoration _cardDecoration({Color border = const Color(0xFFBDC9C8)}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border),
      boxShadow: softShadow(),
    );
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
                iconColor: examActive ? Colors.green.shade600 : Colors.black26,
                valueColor: examActive ? Colors.green.shade700 : Colors.black45,
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
                iconColor: Colors.green.shade600,
                valueColor: Colors.green.shade700,
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
                icon: Icons.edit_note_rounded,
                iconColor: Colors.orange.shade600,
                valueColor: Colors.orange.shade700,
                subtitle: 'Belum mengirim jawaban',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Terkumpul',
                value: '${data.submittedCount}',
                icon: Icons.check_circle_outline_rounded,
                iconColor: Colors.blue.shade600,
                valueColor: Colors.blue.shade700,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBDC9C8)),
        boxShadow: softShadow(),
      ),
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
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.black45,
                  ),
                ),
              ),
              Icon(icon, size: 15, color: iconColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
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
            style: const TextStyle(fontSize: 10, color: Colors.black45),
          ),
        ],
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
  final String search;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSearch;

  const _FilterBar({
    required this.data,
    required this.filter,
    required this.search,
    required this.onFilter,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('all', 'Semua'),
      ('in_progress', 'Mengerjakan'),
      ('submitted', 'Terkumpul'),
      ('violations', 'Berpelanggaran'),
      ('high_violations', 'Pelanggaran Tinggi'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBDC9C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (id, label) in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => onFilter(id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: filter == id ? kAuthPrimary : kPrimarySoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color:
                                filter == id ? Colors.white : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: onSearch,
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Cari nama peserta...',
              prefixIcon:
                  const Icon(Icons.search, size: 17, color: Colors.black38),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              filled: true,
              fillColor: const Color(0xFFF7FBFB),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFBDC9C8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kAuthPrimary),
              ),
            ),
          ),
        ],
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

  const _SessionCard({required this.session, required this.maxTabSwitch});

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = false;

  ExamMonitoringSession get s => widget.session;
  bool get _high =>
      s.violationCount >= widget.maxTabSwitch ||
      s.tabSwitchCount >= widget.maxTabSwitch;
  bool get _submitted => s.status == 'submitted';

  @override
  Widget build(BuildContext context) {
    final name = (s.respondentName?.isNotEmpty ?? false)
        ? s.respondentName!
        : 'Anonim';
    final hasViolations = s.violationCount > 0;
    return Container(
      decoration: BoxDecoration(
        color: _high ? const Color(0xFFFDF3F2) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _high ? Colors.red.shade300 : const Color(0xFFBDC9C8),
          width: _high ? 1.3 : 1,
        ),
        boxShadow: softShadow(),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: hasViolations ? () => setState(() => _expanded = !_expanded) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                        radius: 17,
                        backgroundColor: kPrimarySoft,
                        child: Text(
                          name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: kAuthPrimary,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: _submitted
                                ? Colors.blueGrey.shade300
                                : (s.isOnline
                                    ? Colors.green.shade500
                                    : Colors.grey.shade400),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _submitted
                              ? 'Terkumpul ${_relativeTime(s.submittedAt ?? s.lastSeenAt)}'
                              : (s.isOnline
                                  ? 'Aktivitas ${_relativeTime(s.lastSeenAt)}'
                                  : 'Terakhir aktif ${_relativeTime(s.lastSeenAt)}'),
                          style: const TextStyle(
                              fontSize: 10.5, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _submitted
                          ? Colors.blueGrey.shade50
                          : (s.isOnline
                              ? Colors.green.shade50
                              : Colors.orange.shade50),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _submitted
                            ? Colors.blueGrey.shade200
                            : (s.isOnline
                                ? Colors.green.shade200
                                : Colors.orange.shade200),
                      ),
                    ),
                    child: Text(
                      _submitted
                          ? 'Terkumpul'
                          : (s.isOnline ? 'Online' : 'Offline'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _submitted
                            ? Colors.blueGrey.shade600
                            : (s.isOnline
                                ? Colors.green.shade700
                                : Colors.orange.shade700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Ringkasan pelanggaran + tanda merah bila tinggi.
              Row(
                children: [
                  Expanded(
                    child: _violationStat(
                      'Total pelanggaran',
                      '${s.violationCount}',
                      s.violationCount > 0 ? Colors.red : Colors.black38,
                    ),
                  ),
                  Expanded(
                    child: _violationStat(
                      'Pindah tab',
                      '${s.tabSwitchCount}',
                      s.tabSwitchCount > 0 ? Colors.red : Colors.black38,
                    ),
                  ),
                  if (hasViolations)
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(Icons.chevron_right,
                          size: 18, color: Colors.black38),
                    ),
                ],
              ),
              if (_high)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 13, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Pelanggaran tinggi (batas ${widget.maxTabSwitch}x)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              // Log pelanggaran (expand).
              if (_expanded && hasViolations) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FBFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE3ECEB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final v in s.violations)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(Icons.flag_rounded,
                                  size: 12, color: Colors.red.shade400),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _violationLabel(v.type),
                                  style: const TextStyle(
                                      fontSize: 11.5, color: Colors.black87),
                                ),
                              ),
                              Text(
                                _clockTime(v.occurredAt),
                                style: const TextStyle(
                                    fontSize: 10.5, color: Colors.black45),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _violationStat(String label, String value, Color color) => Row(
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
              style: const TextStyle(fontSize: 10.5, color: Colors.black45),
            ),
          ),
        ],
      );
}
