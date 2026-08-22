import 'package:flutter/material.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

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
        if (q.pendingImageBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              q.pendingImageBytes!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 120,
                alignment: Alignment.center,
                color: const Color(0xFFF0F4F4),
                child: const Icon(Icons.broken_image_outlined,
                    size: 32, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ] else if (q.questionImage != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              profileImageUrl(q.questionImage),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: 800,
              errorBuilder: (_, _, _) => Container(
                height: 120,
                alignment: Alignment.center,
                color: const Color(0xFFF0F4F4),
                child: const Icon(Icons.broken_image_outlined,
                    size: 32, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (hasAudio) ...[
          Row(
            children: [
              const Icon(Icons.audio_file, size: 18, color: kAuthPrimary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Audio terlampir',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                onPressed: () {
                  q.questionAudio = null;
                  q.pendingAudioBytes = null;
                  q.pendingAudioName = null;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        if (uploading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (hasImage)
                TextButton.icon(
                  onPressed: () {
                    q.questionImage = null;
                    q.pendingImageBytes = null;
                    q.pendingImageName = null;
                    onChanged();
                  },
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFFC0392B)),
                  label: const Text(
                    'Hapus Gambar',
                    style: TextStyle(fontSize: 12, color: Color(0xFFC0392B)),
                  ),
                ),
              if (hasAudio)
                TextButton.icon(
                  onPressed: () {
                    q.questionAudio = null;
                    q.pendingAudioBytes = null;
                    q.pendingAudioName = null;
                    onChanged();
                  },
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFFC0392B)),
                  label: const Text(
                    'Hapus Audio',
                    style: TextStyle(fontSize: 12, color: Color(0xFFC0392B)),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: onPickImage,
                icon: const Icon(Icons.image_outlined, size: 16, color: kAuthPrimary),
                label: Text(
                  hasImage ? 'Ganti Gambar' : 'Tambah Gambar',
                  style: const TextStyle(fontSize: 12, color: kAuthPrimary),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPickAudio,
                icon: const Icon(Icons.audio_file_outlined, size: 16, color: kAuthPrimary),
                label: Text(
                  hasAudio ? 'Ganti Audio' : 'Tambah Audio',
                  style: const TextStyle(fontSize: 12, color: kAuthPrimary),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
