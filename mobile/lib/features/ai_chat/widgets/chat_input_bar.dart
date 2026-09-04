import 'package:flutter/material.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/ai_chat/controllers/mention_highlight_controller.dart';

/// Kolom input bawah: dropdown autocomplete @mention + hint mention
/// + pill text field gaya Gemini.
class ChatInputBar extends StatelessWidget {
  final MentionHighlightController textController;
  final bool streaming;

  // State @mention.
  final bool mentionActive;
  final List<FormData> mentionCandidates;
  final String mentionQuery;
  final bool isLoadingForms;
  final bool formsLoadFailed;
  final String? formsLoadError;
  final int pickedMentionCount;
  final bool hasAtSign;

  final VoidCallback onSend;

  /// Hentikan respons AI yang sedang streaming (tombol stop saat loading).
  final VoidCallback onStop;
  final ValueChanged<FormData> onSelectMention;
  final VoidCallback onRetryLoadForms;
  final VoidCallback onClearMentions;

  const ChatInputBar({
    super.key,
    required this.textController,
    required this.streaming,
    required this.mentionActive,
    required this.mentionCandidates,
    required this.mentionQuery,
    required this.isLoadingForms,
    required this.formsLoadFailed,
    required this.formsLoadError,
    required this.pickedMentionCount,
    required this.hasAtSign,
    required this.onSend,
    required this.onStop,
    required this.onSelectMention,
    required this.onRetryLoadForms,
    required this.onClearMentions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kAppBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // @mention autocomplete — tooltip scrollable berisi semua form.
          if (mentionActive) _mentionDropdown(),
          // Hint untuk @mention (ketika tidak aktif).
          if (!mentionActive && hasAtSign) _mentionHint(),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                // Spacious Gemini-style pill container.
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0xFFBDC9C8)),
                  boxShadow: softShadow(),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        decoration: const InputDecoration(
                          hintText: 'Tanya ke AI...',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.fromLTRB(18, 14, 8, 14),
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: Colors.black45,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 2, bottom: 2),
                      // Slot tombol sama persis di kedua state agar UI
                      // tidak "loncat" saat mulai/selesai streaming.
                      child: IconButton(
                        onPressed: streaming ? onStop : onSend,
                        tooltip: streaming ? 'Stop' : 'Send',
                        icon: Icon(
                          streaming
                              ? Icons.stop_rounded
                              : Icons.send_rounded,
                          size: 22,
                          color: kAuthPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mentionDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFBDC9C8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: mentionCandidates.isEmpty
              ? InkWell(
                  onTap: formsLoadFailed ? onRetryLoadForms : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          formsLoadFailed
                              ? Icons.error_outline
                              : Icons.search_off,
                          size: 16,
                          color: formsLoadFailed
                              ? Colors.red
                              : Colors.black45,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formsLoadFailed
                                ? 'Gagal memuat form: $formsLoadError — ketuk untuk coba lagi'
                                : isLoadingForms
                                ? 'Memuat form...'
                                : mentionQuery.isEmpty
                                ? 'Kamu belum punya form'
                                : 'Tidak ada form dengan judul "@$mentionQuery"',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Scrollbar(
                  thumbVisibility: true,
                  child: ListView.separated(
                    shrinkWrap: true,
                    primary: false,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: mentionCandidates.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                    ),
                    itemBuilder: (ctx, i) {
                      final f = mentionCandidates[i];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: kPrimarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            size: 14,
                            color: kAuthPrimary,
                          ),
                        ),
                        title: Text(
                          f.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '#${f.id} • ${f.status}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                        onTap: () => onSelectMention(f),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Widget _mentionHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.alternate_email, size: 12, color: Colors.black45),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              pickedMentionCount == 0
                  ? 'Ketik @ untuk mention form'
                  : 'Mention: $pickedMentionCount form terpilih',
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
          if (pickedMentionCount > 0)
            GestureDetector(
              onTap: onClearMentions,
              child: const Text(
                'Hapus',
                style: TextStyle(fontSize: 10, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}
