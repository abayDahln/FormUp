import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/home/controllers/form_sort_filter.dart';

/// Isi bottom sheet Filter & Urutkan pada tab Form Saya
class FormFilterSheetContent extends StatelessWidget {
  final DateTime? filterDate;
  final int sortIndex;
  final Future<void> Function() onPickDate;
  final VoidCallback onClearDate;
  final ValueChanged<int> onSortSelected;
  final VoidCallback onReset;

  const FormFilterSheetContent({
    super.key,
    required this.filterDate,
    required this.sortIndex,
    required this.onPickDate,
    required this.onClearDate,
    required this.onSortSelected,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final hasActive =
        filterDate != null || sortIndex != FormSort.newest.index;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Filter & Urutkan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: Colors.black87,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined, color: kAuthPrimary),
            title: Text(
              filterDate == null
                  ? 'Semua tanggal'
                  : 'Dibuat: ${_formatDate(filterDate!)}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            subtitle: const Text(
              'Filter berdasarkan tanggal pembuatan',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            trailing: filterDate != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                    tooltip: 'Hapus filter tanggal',
                    onPressed: onClearDate,
                  )
                : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            onTap: () => onPickDate(),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Urutkan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: Colors.black54,
              ),
            ),
          ),
          RadioGroup<int>(
            groupValue: sortIndex,
            onChanged: (v) {
              if (v == null) return;
              onSortSelected(v);
            },
            child: Column(
              children: [
                for (final s in FormSort.values)
                  RadioListTile<int>(
                    value: s.index,
                    dense: true,
                    title: Text(
                      s.label,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
              ],
            ),
          ),
          if (hasActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: OutlinedButton(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kAuthPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Reset Filter',
                  style: TextStyle(color: kAuthPrimary, fontSize: 13),
                ),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
