import 'package:flutter/material.dart';
import 'package:form_up/core/services/ai_chat_history_service.dart';
import 'package:form_up/core/widgets/ai_chat_icon.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Drawer riwayat chat AI (M3 navigation drawer): daftar sesi,
/// tombol chat baru, pengaturan, dan hapus semua riwayat.
/// Drawer menutup dirinya sendiri sebelum memanggil callback.
class AiChatDrawer extends StatelessWidget {
  final List<ChatSession> sessions;
  final String? currentSessionId;
  final String modelDisplay;
  final Future<void> Function() onNewSession;
  final Future<void> Function(String id) onSelectSession;
  final Future<void> Function(String id) onDeleteSession;
  final Future<void> Function() onClearAll;
  final VoidCallback onOpenSettings;

  const AiChatDrawer({
    super.key,
    required this.sessions,
    required this.currentSessionId,
    required this.modelDisplay,
    required this.onNewSession,
    required this.onSelectSession,
    required this.onDeleteSession,
    required this.onClearAll,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const AiChatIcon(color: kAuthPrimary, size: 26, filled: true),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FormUp AI',
                        style: TextStyle(
                          fontFamily: kFontBold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        modelDisplay,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 22,
                      color: Colors.black87,
                    ),
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await onNewSession();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Chat baru'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(indent: 16, endIndent: 16, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Riwayat',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            Expanded(
              child: sessions.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada riwayat',
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemCount: sessions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (ctx, i) {
                        final s = sessions[i];
                        final isSelected = s.id == currentSessionId;
                        return Material(
                          color: isSelected
                              ? kPrimary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              Navigator.pop(context);
                              await onSelectSession(s.id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.chat_bubble
                                        : Icons.chat_bubble_outline,
                                    size: 16,
                                    color: isSelected
                                        ? kAuthPrimary
                                        : Colors.black54,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isSelected
                                            ? kAuthPrimary
                                            : Colors.black87,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () =>
                                        _confirmDelete(context, s.id, s.title),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.black38,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            // Bottom settings ala M3: bottom area drawer.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                      size: 24,
                      color: Colors.black87,
                    ),
                    title: const Text(
                      'Pengaturan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onOpenSettings();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      size: 24,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Hapus semua riwayat',
                      style: TextStyle(fontSize: 13),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () => _confirmClearAll(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String id,
    String title,
  ) async {
    final c = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Hapus chat?'),
        content: Text('Hapus "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (c == true) await onDeleteSession(id);
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    Navigator.pop(context);
    final c = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Hapus semua?'),
        content: const Text('Semua riwayat chat akan hilang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (c == true) await onClearAll();
  }
}
