import 'package:flutter/material.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Step kode: input kode form, info form, token, dan nama (opsional)
class RunnerCodeStep extends StatelessWidget {
  final bool showTitle;
  final TextEditingController codeController;
  final TextEditingController tokenController;
  final TextEditingController nameController;
  final PublicFormInfo? info;
  final bool loading;
  final bool requiresToken;
  final bool isLoggedIn;
  final VoidCallback onSubmitCode;
  final VoidCallback onLoadQuestions;

  const RunnerCodeStep({
    super.key,
    required this.showTitle,
    required this.codeController,
    required this.tokenController,
    required this.nameController,
    required this.info,
    required this.loading,
    required this.requiresToken,
    required this.isLoggedIn,
    required this.onSubmitCode,
    required this.onLoadQuestions,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            const AuthTitle(
              title: "Kerjakan Form",
              subtitle: "Masukkan kode form dari pemilik untuk mulai mengerjakan.",
            ),
            const SizedBox(height: 32),
          ],
          AuthCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: codeController,
                  hint: "Kode form",
                  icon: Icons.link,
                ),
                if (info != null) ...[
                  const SizedBox(height: 18),
                  _FormInfoCard(info: info!),
                ],
                if (requiresToken) ...[
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: tokenController,
                    hint: "Token akses",
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Form ini dilindungi token. Masukkan token yang diberikan pemilik form.",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                if (!isLoggedIn && info != null && !info!.requiresLogin) ...[
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: nameController,
                    hint: "Nama Anda (opsional)",
                    icon: Icons.person_outline,
                  ),
                ],
                const SizedBox(height: 22),
                AuthPrimaryButton(
                  label: info == null ? "Lanjut" : "Mulai Mengerjakan",
                  loading: loading,
                  onPressed: info == null ? onSubmitCode : onLoadQuestions,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Butuh bantuan? Hubungi pemilik form untuk mendapatkan kode.",
            style: TextStyle(fontSize: 12, color: Colors.black45),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Kartu ringkas info form pada step kode
class _FormInfoCard extends StatelessWidget {
  final PublicFormInfo info;

  const _FormInfoCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrimarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAuthPrimary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.description_outlined, size: 20, color: kAuthPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichTextView(
                  text: info.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: kFontBold,
                    color: Colors.black87,
                  ),
                ),
                if (info.description != null && info.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  RichTextView(
                    text: info.description!,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (info.oneResponse) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 13,
                        color: Color(0xFFB26A00),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "Form ini hanya dapat diisi satu kali.",
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB26A00),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
