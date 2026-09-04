import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/ai_chat/models/chat_message.dart';
import 'package:form_up/features/ai_chat/widgets/streaming_ai_text.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Satu bubble chat: teks user, teks AI (markdown), indikator mengetik,
/// bubble error + tombol coba lagi, dan kartu aksi AI.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  /// True bila screen sedang streaming (untuk indikator "AI mengetik...").
  final bool streaming;

  /// True bila ini pesan terakhir di list.
  final bool isLast;

  final VoidCallback onRetry;
  final Future<void> Function(ChatMessage message) onRunAction;

  const ChatBubble({
    super.key,
    required this.message,
    required this.streaming,
    required this.isLast,
    required this.onRetry,
    required this.onRunAction,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? kAuthPrimary : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
          boxShadow: softShadow(),
          border: isUser
              ? null
              : Border.all(
                  color: m.isError
                      ? Colors.red.shade300
                      : const Color(0xFFBDC9C8),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              SelectableText(
                m.text.isEmpty ? '...' : m.text,
                style: const TextStyle(fontSize: 13, color: Colors.white),
              )
            else if (m.stream != null)
              // Bubble AKTIF: rebuild terisolasi via notifier —
              // sisa ListView tidak ikut rebuild per chunk.
              StreamingAiText(notifier: m.stream!)
            else if (streaming && isLast && m.text.isEmpty)
              const Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'AI mengetik...',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              )
            else if (m.isError)
              // Bubble error: pesan Indonesia + tombol coba lagi.
              _ErrorBody(message: m, onRetry: onRetry)
            else
              // Render jawaban AI sebagai markdown (bold, list, tabel, code block, LaTeX).
              // Teks kosong seharusnya tidak terjadi (dijaga saat onDone/onError),
              // fallback ini hanya pengaman agar tidak tampil "..." yang membingungkan.
              GptMarkdown(
                m.text.isEmpty ? 'Respons kosong — coba kirim ulang.' : m.text,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            if (m.actionJson != null) ...[
              const SizedBox(height: 8),
              _ActionCard(
                message: m,
                isUser: isUser,
                onRunAction: onRunAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Isi bubble error: ikon + pesan + tombol "Coba lagi".
class _ErrorBody extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 15, color: Colors.red.shade700),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message.text,
                style: TextStyle(fontSize: 13, color: Colors.red.shade800),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Coba lagi', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}

/// Kartu aksi AI (create_form / add_questions / update_settings).
class _ActionCard extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;
  final Future<void> Function(ChatMessage message) onRunAction;

  const _ActionCard({
    required this.message,
    required this.isUser,
    required this.onRunAction,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isUser ? Colors.white24 : const Color(0xFFF0F4F4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                m.actionExecuted ? Icons.check_circle : Icons.auto_awesome,
                size: 14,
                color: m.actionExecuted ? Colors.green : Colors.black54,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Aksi: ${m.actionJson!['action']}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isUser ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (!m.actionExecuted && !isUser)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => onRunAction(m),
                  child: const Text(
                    'Jalankan',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
        if (m.actionResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              m.actionResult!,
              style: TextStyle(
                fontSize: 11,
                color: m.actionResult!.startsWith('Gagal')
                    ? Colors.red
                    : Colors.green,
              ),
            ),
          ),
      ],
    );
  }
}
