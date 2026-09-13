import 'package:flutter/material.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/gemini_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/ai_chat/controllers/mention_highlight_controller.dart';
import 'package:form_up/features/ai_chat/models/ai_attachment.dart';

class ChatInputBar extends StatefulWidget {
  final MentionHighlightController textController;
  final FocusNode? focusNode;
  final bool streaming;
  final bool sending;
  final bool mentionActive;
  final List<FormData> mentionCandidates;
  final String mentionQuery;
  final bool isLoadingForms;
  final bool formsLoadFailed;
  final String? formsLoadError;
  final int pickedMentionCount;
  final bool hasAtSign;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final ValueChanged<FormData> onSelectMention;
  final VoidCallback onRetryLoadForms;
  final List<AiAttachment> attachments;
  final VoidCallback onPickFiles;
  final ValueChanged<String> onRemoveAttachment;
  final bool isListening;
  final VoidCallback onMicPressed;
  final VoidCallback? onModelChanged;
  const ChatInputBar({
    super.key,
    required this.textController,
    this.focusNode,
    required this.streaming,
    this.sending = false,
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
    this.attachments = const [],
    required this.onPickFiles,
    required this.onRemoveAttachment,
    this.isListening = false,
    required this.onMicPressed,
    this.onModelChanged,
  });
  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}
class _ChatInputBarState extends State<ChatInputBar> {
  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_onText);
  }
  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textController != widget.textController) {
      oldWidget.textController.removeListener(_onText);
      widget.textController.addListener(_onText);
    }
  }
  @override
  void dispose() {
    widget.textController.removeListener(_onText);
    super.dispose();
  }
  void _onText() { if (mounted) setState(() {}); }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSend = widget.textController.text.trim().isNotEmpty || widget.attachments.isNotEmpty;
    // Pill mengikuti tema aplikasi (bukan warna statik foto mockup)
    final pillColor = cs.surfaceContainerHighest;
    final borderColor = cs.outlineVariant;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (widget.mentionActive) _mentionDropdown(context),
        if (!widget.mentionActive && widget.hasAtSign) _mentionHint(context),
        SafeArea(top: false, child: Builder(builder: (ctx) {
          final isWide = MediaQuery.sizeOf(ctx).width >= 600;
          final outerPad = isWide ? const EdgeInsets.fromLTRB(24, 8, 24, 16) : const EdgeInsets.fromLTRB(16, 8, 16, 16);
          return Container(padding: outerPad, child: Container(padding: EdgeInsets.fromLTRB(12, widget.attachments.isNotEmpty ? 12 : 8, 8, 8), decoration: BoxDecoration(color: pillColor, borderRadius: BorderRadius.circular(28), border: Border.all(color: borderColor), boxShadow: softShadow()), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.attachments.isNotEmpty) ...[_AttachmentPreview(attachments: widget.attachments, onRemove: widget.onRemoveAttachment), const SizedBox(height: 8)],
          TextField(controller: widget.textController, focusNode: widget.focusNode, minLines: 1, maxLines: 4, textInputAction: TextInputAction.send, onSubmitted: (_) { if (canSend && !widget.streaming && !widget.sending) widget.onSend(); }, decoration: InputDecoration(hintText: 'Ask Gemini', filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.fromLTRB(8, 10, 8, 8), hintStyle: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)), style: TextStyle(fontSize: 15, color: cs.onSurface)),
          const SizedBox(height: 6),
          Row(children: [
            InkWell(onTap: (widget.streaming || widget.sending) ? null : widget.onPickFiles, borderRadius: BorderRadius.circular(20), child: Container(width: 36, height: 36, alignment: Alignment.center, child: Icon(Icons.add, size: 22, color: cs.onSurfaceVariant))),
            const SizedBox(width: 8),
            Flexible(child: Align(alignment: Alignment.centerRight, child: _FlashPickerCompact(onChanged: widget.onModelChanged))),
            const SizedBox(width: 4),
            IconButton(onPressed: (widget.streaming || widget.sending) ? null : widget.onMicPressed, tooltip: widget.isListening ? 'Berhenti merekam' : 'Dikte suara', visualDensity: VisualDensity.compact, icon: Icon(widget.isListening ? Icons.mic : Icons.mic_none_outlined, size: 20, color: widget.isListening ? Colors.red : cs.onSurfaceVariant)),
            const SizedBox(width: 4),
            if (widget.streaming) IconButton(onPressed: widget.onStop, tooltip: 'Stop', style: IconButton.styleFrom(backgroundColor: cs.surfaceContainerHigh), icon: Icon(Icons.stop_rounded, size: 20, color: cs.primary))
            else if (widget.sending) Padding(padding: const EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)))
            else if (canSend) Material(color: cs.primary, shape: const CircleBorder(), clipBehavior: Clip.antiAlias, child: InkWell(onTap: widget.onSend, child: SizedBox(width: 36, height: 36, child: Icon(Icons.arrow_upward, size: 20, color: cs.onPrimary))))
            else const SizedBox(width: 4),
          ]),
        ])));
          }),
        ),
      ]),
    );
  }
  Widget _mentionDropdown(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Material(color: cs.surface, elevation: 4, shadowColor: Colors.black26, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outlineVariant)), clipBehavior: Clip.antiAlias, child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 220), child: widget.mentionCandidates.isEmpty ? InkWell(onTap: widget.formsLoadFailed ? widget.onRetryLoadForms : null, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [Icon(widget.formsLoadFailed ? Icons.error_outline : Icons.search_off, size: 16, color: widget.formsLoadFailed ? Colors.red : cs.onSurfaceVariant), const SizedBox(width: 8), Expanded(child: Text(widget.formsLoadFailed ? 'Gagal memuat form. Ketuk untuk coba lagi' : widget.isLoadingForms ? 'Memuat form...' : widget.mentionQuery.isEmpty ? 'Kamu belum punya form' : 'Tidak ada form dengan judul "@${widget.mentionQuery}"', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)))]))) : Scrollbar(thumbVisibility: true, child: ListView.separated(shrinkWrap: true, primary: false, padding: const EdgeInsets.symmetric(vertical: 6), itemCount: widget.mentionCandidates.length, separatorBuilder: (_, _) => const Divider(height: 1, indent: 12, endIndent: 12), itemBuilder: (ctx, i) { final f = widget.mentionCandidates[i]; return ListTile(dense: true, leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.description_outlined, size: 14, color: cs.primary)), title: Text(f.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: kFontBold)), subtitle: Text('#${f.id} • ${f.status}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)), onTap: () => widget.onSelectMention(f)); })))));
  }
  Widget _mentionHint(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: [Icon(Icons.alternate_email, size: 12, color: cs.onSurfaceVariant), const SizedBox(width: 6), Expanded(child: Text(widget.pickedMentionCount == 0 ? 'Ketik @ untuk mention form' : 'Mention: ${widget.pickedMentionCount} form terpilih', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)))]));
  }
}
class _AttachmentPreview extends StatelessWidget {
  final List<AiAttachment> attachments;
  final ValueChanged<String> onRemove;
  const _AttachmentPreview({required this.attachments, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(spacing: 8, runSpacing: 8, children: [for (final a in attachments) Stack(clipBehavior: Clip.none, children: [Container(width: 96, height: 96, decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant)), clipBehavior: Clip.antiAlias, child: a.isPreviewableImage && a.hasBytes ? Image.memory(a.bytes, fit: BoxFit.cover) : a.isPdf && a.hasBytes ? _PdfThumbPlaceholder(name: a.name) : _FileIconPlaceholder(attachment: a)), Positioned(top: -6, right: -6, child: Material(color: cs.surface, shape: const CircleBorder(), elevation: 2, child: InkWell(customBorder: const CircleBorder(), onTap: () => onRemove(a.id), child: Container(width: 22, height: 22, alignment: Alignment.center, child: Icon(Icons.close, size: 14, color: cs.onSurface)))))] )]);
  }
}
class _PdfThumbPlaceholder extends StatelessWidget {
  final String name;
  const _PdfThumbPlaceholder({required this.name});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(color: cs.surfaceContainerHigh, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.picture_as_pdf, color: cs.onSurfaceVariant, size: 28), const SizedBox(height: 4), Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)))])));
  }
}
class _FileIconPlaceholder extends StatelessWidget {
  final AiAttachment attachment;
  const _FileIconPlaceholder({required this.attachment});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    IconData icon;
    if (attachment.isPdf) icon = Icons.picture_as_pdf_outlined;
    else if (attachment.isDoc) icon = Icons.description_outlined;
    else if (attachment.isExcel) icon = Icons.table_chart_outlined;
    else if (attachment.isImage) icon = Icons.image_outlined;
    else icon = Icons.insert_drive_file_outlined;
    return Container(color: cs.surfaceContainer, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 28, color: cs.onSurfaceVariant), const SizedBox(height: 4), Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(attachment.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)))])));
  }
}
class _FlashPickerCompact extends StatelessWidget {
  final VoidCallback? onChanged;
  const _FlashPickerCompact({this.onChanged});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = GeminiService.selectedModelDisplay;
    return PopupMenuButton<String>(
      tooltip: 'Pilih model',
      offset: const Offset(0, -140),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) async {
        await GeminiService.setModel(v);
        onChanged?.call();
      },
      itemBuilder: (ctx) {
        final mcs = Theme.of(ctx).colorScheme;
        return [
          for (final m in GeminiService.availableModels)
            PopupMenuItem<String>(
              value: m,
              child: Row(children: [
                Icon(m == GeminiService.selectedModelDisplay ? Icons.check : Icons.auto_awesome_outlined, size: 14, color: m == GeminiService.selectedModelDisplay ? mcs.primary : mcs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(m, style: TextStyle(fontSize: 13, fontWeight: m == GeminiService.selectedModelDisplay ? FontWeight.bold : FontWeight.normal, color: m == GeminiService.selectedModelDisplay ? mcs.primary : mcs.onSurface)),
              ]),
            ),
        ];
      },
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Tampilkan nama model lengkap (ex: Gemini 2.5 Flash) di dalam field, bukan Flash saja
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant))),
        const SizedBox(width: 2),
        Icon(Icons.keyboard_arrow_down, size: 16, color: cs.onSurfaceVariant),
      ]),
    );
  }
}
