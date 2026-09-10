import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_up/core/services/exam_lock_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Strip info selama ujian terkunci/pin: jam + tanggal di KIRI,
/// baterai di KANAN (+ hitungan pelanggaran bila ada).
/// Pengganti status bar sistem yang disembunyikan pin/FLAG_SECURE.
/// Baterai via method channel (tanpa plugin, tanpa permission).
class ExamLockStatusBar extends StatefulWidget {
  /// Label hitungan pelanggaran, mis. "2/3". Null = sembunyikan.
  final String? violationLabel;

  const ExamLockStatusBar({super.key, this.violationLabel});

  @override
  State<ExamLockStatusBar> createState() => _ExamLockStatusBarState();
}

class _ExamLockStatusBarState extends State<ExamLockStatusBar> {
  Timer? _clock;
  Timer? _batteryTimer;
  DateTime _now = DateTime.now();
  int _battery = -1;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _refreshBattery();
    _batteryTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshBattery();
    });
  }

  Future<void> _refreshBattery() async {
    final level = await ExamLockService.getBatteryLevel();
    if (mounted) setState(() => _battery = level);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _batteryTimer?.cancel();
    super.dispose();
  }

  String get _time {
    final t = _now.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String get _date {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final t = _now.toLocal();
    return '${t.day} ${months[t.month - 1]}';
  }

  IconData _batteryIcon() {
    if (_battery < 0) return Icons.battery_unknown_outlined;
    if (_battery >= 95) return Icons.battery_full_rounded;
    if (_battery >= 60) return Icons.battery_5_bar_rounded;
    if (_battery >= 30) return Icons.battery_3_bar_rounded;
    return Icons.battery_1_bar_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lowBattery = _battery >= 0 && _battery < 20;
    return Container(
      width: double.infinity,
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
      child: Row(
        children: [
          // Kiri: gembok + tanggal + jam.
          Icon(Icons.lock_outline, size: 13, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            '$_date • $_time',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (widget.violationLabel != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.violationLabel!,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: cs.onErrorContainer,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
          const Spacer(),
          // Kanan: baterai.
          Icon(
            _batteryIcon(),
            size: 15,
            color: lowBattery ? cs.error : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Text(
            _battery < 0 ? '--' : '$_battery%',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: lowBattery ? cs.error : cs.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
