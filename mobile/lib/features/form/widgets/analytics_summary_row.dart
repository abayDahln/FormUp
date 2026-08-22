import 'package:flutter/material.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Baris tiga kartu statistik ringkasan analisis
class AnalyticsSummaryRow extends StatelessWidget {
  final FormAnalytics analytics;

  const AnalyticsSummaryRow({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Respons',
            value: '${a.totalResponses}',
            icon: Icons.people_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Soal',
            value: '${a.totalQuestions}',
            icon: Icons.list_alt_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Rata-rata Skor',
            value: a.averageScore == null
                ? '—'
                : '${a.averageScore!.toStringAsFixed(1)}%',
            icon: Icons.insights_outlined,
          ),
        ),
      ],
    );
  }
}

/// Satu kartu statistik
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: softShadow(),
      ),
      child: Column(
        children: [
          Icon(icon, color: kAuthPrimary, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
