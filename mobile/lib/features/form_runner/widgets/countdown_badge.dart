import 'dart:async';
import 'package:flutter/material.dart';

/// Countdown mandiri (durasi dalam detik)
class CountdownBadge extends StatefulWidget {
  final int seconds;
  final VoidCallback onExpired;

  const CountdownBadge({
    super.key,
    required this.seconds,
    required this.onExpired,
  });

  @override
  State<CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<CountdownBadge> {
  late int _secondsLeft;
  Timer? _timer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.seconds;
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
    final h = (_secondsLeft ~/ 3600).toString().padLeft(2, '0');
    final m = ((_secondsLeft % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final danger = _secondsLeft <= 60;
    final color = danger ? const Color(0xFFC0392B) : Colors.black87;
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
