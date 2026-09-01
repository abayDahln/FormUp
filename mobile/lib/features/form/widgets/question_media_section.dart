import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/progress_indicator.dart' as progress;
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/features/form_runner/widgets/question_audio_player.dart';

/// Isi section "Media": pratinjau gambar/audio + tombol tambah/ganti/hapus
class QuestionMediaSection extends StatelessWidget {
  final QuestionDraft draft;
  final bool uploading;
  final VoidCallback onPickImage;
  final VoidCallback onPickAudio;
  final VoidCallback onChanged;

  const QuestionMediaSection({
    super.key,
    required this.draft,
    required this.uploading,
    required this.onPickImage,
    required this.onPickAudio,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final q = draft;
    final hasImage = q.questionImage != null || q.pendingImageBytes != null;
    final hasAudio = q.questionAudio != null || q.pendingAudioBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preview gambar
        if (q.pendingImageBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              q.pendingImageBytes!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 120,
                alignment: Alignment.center,
                color: const Color(0xFFF0F4F4),
                child: const Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Pratinjau gambar (belum tersimpan)', style: TextStyle(fontSize: 11, color: Colors.black45, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
        ] else if (q.questionImage != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedRemoteImage(
              url: profileImageUrl(q.questionImage),
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: Container(
                height: 120,
                alignment: Alignment.center,
                color: const Color(0xFFF0F4F4),
                child: const Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Indikator wavy di atas tombol gambar saat upload (save ke DB -> ProgressIndicator)
        if (uploading) ...[
          const progress.ProgressIndicator.linear(semanticsLabel: 'Mengunggah gambar'),
          const SizedBox(height: 8),
        ],
        // Tombol gambar: tata letak row sejajar
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: uploading ? null : onPickImage,
                icon: Icon(hasImage ? Icons.image_outlined : Icons.add_photo_alternate_outlined, size: 16, color: kAuthPrimary),
                label: Text(
                  hasImage ? 'Ganti Gambar' : 'Tambah Gambar',
                  style: const TextStyle(fontSize: 12, color: kAuthPrimary, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kAuthPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () {
                          q.questionImage = null;
                          q.pendingImageBytes = null;
                          q.pendingImageName = null;
                          onChanged();
                        },
                  icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFC0392B)),
                  label: const Text(
                    'Hapus Gambar',
                    style: TextStyle(fontSize: 12, color: Color(0xFFC0392B), fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFC0392B)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        // Preview audio
        if (hasAudio) ...[
          if (q.pendingAudioBytes != null) ...[
            QuestionAudioPlayer(
              bytes: q.pendingAudioBytes,
              label: q.pendingAudioName ?? 'Audio pending (belum tersimpan)',
            ),
          ] else if (q.questionAudio != null) ...[
            QuestionAudioPlayer(
              url: q.questionAudio!,
              label: 'Audio tersimpan',
            ),
          ],
          const SizedBox(height: 8),
        ],
        // Indikator wavy di atas tombol audio saat upload (save ke DB -> ProgressIndicator)
        if (uploading) ...[
          const progress.ProgressIndicator.linear(semanticsLabel: 'Mengunggah audio'),
          const SizedBox(height: 8),
        ],
        // Tombol audio: tata letak row sejajar
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: uploading ? null : onPickAudio,
                icon: Icon(hasAudio ? Icons.audio_file_outlined : Icons.add_circle_outline, size: 16, color: kAuthPrimary),
                label: Text(
                  hasAudio ? 'Ganti Audio' : 'Tambah Audio',
                  style: const TextStyle(fontSize: 12, color: kAuthPrimary, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kAuthPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            if (hasAudio) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () {
                          q.questionAudio = null;
                          q.pendingAudioBytes = null;
                          q.pendingAudioName = null;
                          onChanged();
                        },
                  icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFC0392B)),
                  label: const Text(
                    'Hapus Audio',
                    style: TextStyle(fontSize: 12, color: Color(0xFFC0392B), fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFC0392B)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
