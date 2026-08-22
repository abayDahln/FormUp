import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Tile pemilih tanggal lahir
class BirthdateField extends StatelessWidget {
  final DateTime? birthdate;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const BirthdateField({
    super.key,
    required this.birthdate,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(7.5),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F4),
          borderRadius: BorderRadius.circular(7.5),
          border: Border.all(color: kAuthText),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, color: kAuthText),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                birthdate == null ? 'Belum diatur' : _displayDate(birthdate!),
                style: TextStyle(
                  fontSize: 15,
                  color: birthdate == null ? kAuthHint : Colors.black87,
                ),
              ),
            ),
            if (birthdate != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: kAuthText),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}

String _displayDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return "${d.day} ${months[d.month - 1]} ${d.year}";
}
