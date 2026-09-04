// ignore_for_file: invalid_use_of_protected_member
part of '../ai_chat_screen.dart';

/// Manajemen sesi chat: muat, simpan, buat baru, ganti, dan hapus.
extension _AiChatSessions on _AiChatScreenState {
  Future<void> loadSessions() async {
    final all = await AiChatHistoryService.loadAll();
    if (!mounted) return;
    setState(() => _sessions = all);
    if (_sessions.isEmpty) {
      // Jangan auto-buat session kosong (anti spam) — buat id in-memory saja
      if (_currentSessionId == null) {
        setState(() {
          _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
          _messages.clear();
        });
      }
    } else if (_currentSessionId == null) {
      // load most recent
      await switchSession(_sessions.first.id);
    }
  }

  Future<void> persistCurrent() async {
    if (_currentSessionId == null) return;
    if (_messages.isEmpty) return;
    final title = _messages
        .firstWhere((m) => m.role == 'user', orElse: () => _messages.first)
        .text
        .trim();
    final short = title.length > 40 ? '${title.substring(0, 40)}…' : title;
    final session = ChatSession(
      id: _currentSessionId!,
      title: short.isEmpty ? 'Chat baru' : short,
      messages: _messages
          .map((m) => ChatHistoryMessage(role: m.role, text: m.text))
          .toList(),
      updatedAt: DateTime.now(),
    );
    await AiChatHistoryService.upsert(session);
    final all = await AiChatHistoryService.loadAll();
    if (mounted) setState(() => _sessions = all);
  }

  Future<void> newSession() async {
    // Anti spam: chat baru hanya jika sudah ada prompt yang dikirim
    if (_messages.isEmpty) {
      // Jika sudah ada session kosong yang belum tersimpan, jangan buat lagi
      if (_sessions.isEmpty || _currentSessionId != null) {
        if (mounted && _sessions.isNotEmpty) {
          showAuthToast(context, 'Chat masih kosong');
        }
        // Jika belum ada session sama sekali, cukup reset id in-memory
        if (_sessions.isEmpty) {
          setState(() {
            _currentSessionId = DateTime.now().millisecondsSinceEpoch
                .toString();
            _messages.clear();
          });
        }
        return;
      }
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    if (!mounted) return;
    await stopActiveStream();
    setState(() {
      _currentSessionId = id;
      _messages.clear();
      _showFab = false;
    });
    // Jangan langsung upsert kosong — akan tersimpan otomatis saat prompt pertama dikirim (persistCurrent)
  }

  /// Hentikan stream aktif + buang notifier live (dipakai saat ganti/
  /// hapus sesi agar tidak ada listener yatim yang menulis ke pesan lama).
  Future<void> stopActiveStream() async {
    await _sub?.cancel();
    _sub = null;
    for (final m in _messages) {
      m.disposeStream();
    }
    if (mounted && _streaming) setState(() => _streaming = false);
  }

  Future<void> switchSession(String id) async {
    await stopActiveStream();
    final all = await AiChatHistoryService.loadAll();
    final target = all.firstWhere((e) => e.id == id, orElse: () => all.first);
    if (!mounted) return;
    setState(() {
      _currentSessionId = id;
      _messages
        ..clear()
        ..addAll(
          target.messages.map((m) => ChatMessage(role: m.role, text: m.text)),
        );
      _showFab = false;
    });
    // Langsung tampilkan chat terbaru (paling bawah) saat ganti sesi
    _scrollToBottom(immediate: true);
  }

  Future<void> deleteSession(String id) async {
    await AiChatHistoryService.delete(id);
    if (_currentSessionId == id) {
      await stopActiveStream();
      setState(() {
        _messages.clear();
        _currentSessionId = null;
      });
      final all = await AiChatHistoryService.loadAll();
      if (!mounted) return;
      if (all.isEmpty) {
        await newSession();
      } else {
        await switchSession(all.first.id);
      }
    }
    await loadSessions();
  }

  /// Hapus seluruh riwayat (dipanggil dari drawer setelah konfirmasi).
  Future<void> clearAllSessions() async {
    await AiChatHistoryService.clearAll();
    setState(() {
      _messages.clear();
      _sessions.clear();
      _currentSessionId = null;
    });
    await newSession();
    if (mounted) showAuthToast(context, 'Semua history dihapus');
  }
}
