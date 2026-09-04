import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/ai_chat/models/chat_message.dart';
import 'package:form_up/features/ai_chat/widgets/action_change_card.dart';
import 'package:form_up/features/ai_chat/widgets/form_context_card.dart';
import 'package:form_up/features/ai_chat/widgets/streaming_ai_text.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

const _aiTextStyle = TextStyle(fontSize: 13, color: Colors.black87);

/// Satu bubble chat: teks user, teks AI (markdown), indikator mengetik,
/// bubble error + tombol coba lagi, dan kartu status aksi AI.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  /// True bila screen sedang streaming (untuk indikator "AI mengetik...").
  final bool streaming;

  /// True bila ini pesan terakhir di list.
  final bool isLast;

  final VoidCallback onRetry;

  /// Undo perubahan form dari aksi AI di bubble ini (null = sembunyikan).
  final VoidCallback? onUndo;

  /// Redo perubahan yang sudah di-undo (null = sembunyikan).
  final VoidCallback? onRedo;

  /// Long-press pesanku → menu rollback.
  final VoidCallback? onUserLongPress;

  /// Tombol di bawah pesanku: coba lagi / edit / salin prompt.
  final VoidCallback? onPromptRetry;
  final VoidCallback? onPromptEdit;
  final VoidCallback? onPromptCopy;

  const ChatBubble({
    super.key,
    required this.message,
    required this.streaming,
    required this.isLast,
    required this.onRetry,
    this.onUndo,
    this.onRedo,
    this.onUserLongPress,
    this.onPromptRetry,
    this.onPromptEdit,
    this.onPromptCopy,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    final isUser = m.role == 'user';
    final bubble = GestureDetector(
        onLongPress: isUser ? onUserLongPress : null,
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
              // Render jawaban AI sebagai markdown (bold, list, tabel, code
              // block, LaTeX). Blok <FORM_CONTEXT> yang ter-echo dipisah dan
              // digambar sebagai kartu form yang bisa diketuk ke detail.
              ..._buildAiBody(m),
            // Kartu ringkasan perubahan (diff) untuk aksi AI: ringkasan +
            // status + Undo + dropdown detail + tombol Buka Form.
            if (!isUser && m.actionJson != null) ...[
              const SizedBox(height: 8),
              ActionChangeCard(message: m, onUndo: onUndo, onRedo: onRedo),
            ],
          ],
        ),
        ),
    );

    if (!isUser) {
      return Align(alignment: Alignment.centerLeft, child: bubble);
    }

    // Pesanku: bubble + baris aksi kecil di bawahnya
    // (coba lagi / edit / salin prompt) seperti gaya ChatGPT.
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          bubble,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onPromptRetry != null)
                _MiniPromptAction(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Coba lagi',
                  onTap: onPromptRetry!,
                ),
              if (onPromptEdit != null)
                _MiniPromptAction(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit prompt',
                  onTap: onPromptEdit!,
                ),
              if (onPromptCopy != null)
                _MiniPromptAction(
                  icon: Icons.copy_rounded,
                  tooltip: 'Salin prompt',
                  onTap: onPromptCopy!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Pecah teks jawaban AI di setiap blok `<FORM_CONTEXT>…</FORM_CONTEXT>`:
  /// segmen teks biasa dirender GptMarkdown, blok konteks dirender sebagai
  /// FormContextCard (judul saja tanpa id, ketuk → detail form).
  List<Widget> _buildAiBody(ChatMessage m) {
    final text = m.text.isEmpty ? 'Respons kosong — coba kirim ulang.' : m.text;
    final widgets = <Widget>[];
    final regex = RegExp(r'<FORM_CONTEXT>([\s\S]*?)</FORM_CONTEXT>');
    var last = 0;
    for (final match in regex.allMatches(text)) {
      final before = text.substring(last, match.start).trim();
      if (before.isNotEmpty) {
        widgets.add(GptMarkdown(before, style: _aiTextStyle));
      }
      widgets.add(FormContextCard.fromBlock(match.group(1) ?? ''));
      last = match.end;
    }
    final rest = text.substring(last).trim();
    if (rest.isNotEmpty || widgets.isEmpty) {
      widgets.add(GptMarkdown(rest, style: _aiTextStyle));
    }
    return widgets;
  }
}

/// Satu tombol ikon kecil di bawah bubble pesan user.
class _MiniPromptAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniPromptAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 28,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        iconSize: 15,
        color: Colors.black38,
        icon: Icon(icon),
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
