import 'package:flutter/material.dart';

/// Baris info status form: 1x kesempatan & harus login
class FormStartStatusInfo extends StatelessWidget {
  final bool oneResponse;
  final bool requiresLogin;

  const FormStartStatusInfo({
    super.key,
    required this.oneResponse,
    required this.requiresLogin,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (oneResponse && requiresLogin) const SizedBox(width: 8),
        if (requiresLogin) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child:  Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: cs.primary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Harus login",
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
