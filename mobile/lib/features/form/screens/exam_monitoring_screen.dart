import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Pantauan live mode ujian untuk owner: polling tiap 15 detik.
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

class _ExamMonitoringScreenState extends State<ExamMonitoringScreen> {
  ExamMonitoringData? _data;
  bool _loading = true;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _fetch();
    _poller = Timer.periodic(const Duration(seconds: 15), (_) => _fetch(silent: true));
  }

  @override
  void dispose() {
    _poller?.cancel();
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent) showAuthToast(context, AuthService.errorMessage(e), isError: true);
    }
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
        title: Text(
          widget.title.isEmpty ? 'Pantau Ujian' : 'Pantau: ${widget.title}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        actions: [
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  if (data != null) _SummaryCard(data: data),
                  const SizedBox(height: 12),
                  if (data == null || data.sessions.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Belum ada sesi ujian.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    )
                  else
                    for (final s in data.sessions) _SessionCard(session: s),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ExamMonitoringData data;

  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _Stat('Online', '${data.onlineCount}'),
            _Stat('Mengerjakan', '${data.inProgressCount}'),
            _Stat('Terkumpul', '${data.submittedCount}'),
            if (data.maxTabSwitch != null)
              _Stat('Batas pindah', '${data.maxTabSwitch}'),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: kFontBold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ExamMonitoringSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final name = (session.respondentName?.isNotEmpty ?? false)
        ? session.respondentName!
        : 'Anonim';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontFamily: kFontBold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: session.status == 'submitted'
                        ? Colors.grey.shade200
                        : (session.isOnline ? Colors.green.shade100 : Colors.orange.shade100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.status == 'submitted'
                        ? 'Terkumpul'
                        : (session.isOnline ? 'Online' : 'Offline'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Pelanggaran: ${session.violationCount} • Pindah aplikasi: ${session.tabSwitchCount}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (session.violations.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final v in session.violations)
                Text('• ${v.type}',
                    style: const TextStyle(fontSize: 12, color: Colors.black87)),
            ],
          ],
        ),
      ),
    );
  }
}
