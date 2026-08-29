import 'package:flutter/material.dart';
import 'package:form_up/core/theme.dart';

/// M3 outlined date picker field — selaras dengan AuthTextField
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
      borderRadius: BorderRadius.circular(kRadiusSm),
      child: InputDecorator(
        decoration: formUpInputDecoration(
          labelText: 'Tanggal Lahir',
          hintText: 'Belum diatur',
          prefixIcon: const Icon(Icons.cake_outlined, size: 20),
          suffixIcon: birthdate != null
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                  tooltip: 'Hapus',
                )
              : null,
        ),
        child: Text(
          birthdate == null ? 'Belum diatur' : _displayDate(birthdate!),
          style: TextStyle(
            fontSize: 14,
            color: birthdate == null ? Colors.black38 : Colors.black87,
          ),
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
