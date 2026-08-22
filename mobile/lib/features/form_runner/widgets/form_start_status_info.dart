import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

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
    return Row(
      children: [
        if (oneResponse) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F4E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Color(0xFF2E7D32),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Hanya 1x kesempatan",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (oneResponse && requiresLogin) const SizedBox(width: 8),
        if (requiresLogin) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: kAuthPrimary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Harus login",
                      style: TextStyle(
                        fontSize: 12,
                        color: kAuthPrimary,
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
