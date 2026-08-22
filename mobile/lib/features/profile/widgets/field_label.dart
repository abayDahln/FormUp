import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Label kecil di atas input form profil
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: kAuthPrimary,
          ),
        ),
      ),
    );
  }
}
