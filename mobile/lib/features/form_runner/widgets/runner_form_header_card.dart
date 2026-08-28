import 'package:flutter/material.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/core/widgets/rich_editor.dart';
import 'package:form_up/features/form_runner/controllers/runner_answer_store.dart';

/// Kartu header form pada step pengisian
class RunnerFormHeaderCard extends StatelessWidget {
  final PublicFormInfo info;
  final int questionCount;

  const RunnerFormHeaderCard({
    super.key,
    required this.info,
    required this.questionCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner form (jika diisi)
          if (info.bannerImage != null && info.bannerImage!.trim().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: CachedRemoteImage(
                  url: profileImageUrl(info.bannerImage),
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    color: kPrimarySoft,
                    child: const Icon(
                      Icons.image_outlined,
                      size: 36,
                      color: kAuthPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          RichTextView(
            text: info.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          // Deskripsi form (jika diisi)
          if (info.description != null && info.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            RichTextView(
              text: info.description!,
              ignoreInlineFontSize: true,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
          if (info.timerDuration != null && info.timerDuration! > 0) ...[
            const SizedBox(height: 6),
            Text(
              "⏱ ${formatRunnerDuration(info.timerDuration!)}",
              style: const TextStyle(fontSize: 12, color: kAuthPrimary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            "$questionCount pertanyaan",
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
