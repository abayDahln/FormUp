import 'package:flutter/material.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/core/widgets/full_screen_image_viewer.dart';
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner form (jika diisi) — tap untuk full-screen
          if (info.bannerImage != null && info.bannerImage!.trim().isNotEmpty) ...[
            GestureDetector(
              onTap: () => showFullScreenImage(context, profileImageUrl(info.bannerImage)),
              child: Hero(
                tag: profileImageUrl(info.bannerImage),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 7,
                    child: CachedRemoteImage(
                      url: profileImageUrl(info.bannerImage),
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: cs.primaryContainer,
                        child:  Icon(
                          Icons.image_outlined,
                          size: 36,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          RichTextView(
            text: info.title,
            style:  TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: cs.onSurface,
            ),
          ),
          // Deskripsi form (jika diisi)
          if (info.description != null && info.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            RichTextView(
              text: info.description!,
              ignoreInlineFontSize: true,
              style:  TextStyle(
                fontSize: 15,
                color: cs.onSurface,
                height: 1.4,
              ),
            ),
          ],
          if (info.timerDuration != null && info.timerDuration! > 0) ...[
            const SizedBox(height: 6),
            Text(
              "⏱ ${formatRunnerDuration(info.timerDuration!)}",
              style:  TextStyle(fontSize: 12, color: cs.primary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            "$questionCount pertanyaan",
            style:  TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
