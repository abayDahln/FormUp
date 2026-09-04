// ignore_for_file: invalid_use_of_protected_member
part of '../ai_chat_screen.dart';

/// Operasi riwayat chat: tombol di bawah pesanku (coba lagi / edit / salin),
/// rollback, dan undo perubahan form dari aksi AI — lengkap dengan dialog
/// konfirmasi yang merinci perubahan undo yang akan terjadi.
extension _AiChatHistoryOps on _AiChatScreenState {
  /// Undo SATU perubahan AI yang sudah diterima (tombol di bawah bubble AI).
  /// Hanya menyentuh entitas yang kena aksi tersebut — soal buatan user
  /// manual tidak pernah terganggu.
  Future<void> undoActionChange(ChatMessage m) async {
    if (_actionWorking || m.actionUndone || m.undoSnapshot == null) return;
    final confirmed = await _confirmUndoDialog(
      title: 'Undo perubahan ini?',
      message: 'Perubahan form dari respons AI ini akan dibatalkan.',
      changes: [_describeUndo(m)],
      confirmLabel: 'Undo',
    );
    if (!confirmed || !mounted) return;
    setState(() => _actionWorking = true);
    try {
      await _applyUndo(m);
      m.actionUndone = true;
      if (mounted) showAuthToast(context, 'Perubahan AI di-undo');
    } catch (e) {
      if (mounted) {
        showAuthToast(
          context,
          'Gagal undo: ${AuthService.errorMessage(e)}',
          isError: true,
        );
      }
    }
    if (!mounted) return;
    setState(() => _actionWorking = false);
    await persistCurrent();
  }

  /// Redo: terapkan KEMBALI perubahan AI yang sudah di-undo lewat tombol
  /// kartu. Eksekusi ulang actionJson yang sama — snapshot undo diambil
  /// segar dari kondisi saat ini, sehingga siklus undo↔redo bisa berulang.
  /// (Perubahan yang di-undo lewat edit prompt / rollback tidak punya kartu
  /// lagi karena chat-nya dipotong — jadi memang tidak bisa di-redo; jawaban
  /// AI atas prompt yang diedit menghasilkan aksi baru dengan siklusnya sendiri.)
  Future<void> redoActionChange(ChatMessage m) async {
    if (_actionWorking || !m.actionUndone || m.actionJson == null) return;
    final confirmed = await _confirmUndoDialog(
      title: 'Redo perubahan ini?',
      message: 'Perubahan AI yang tadi di-undo akan diterapkan kembali ke form.',
      changes: [_describeRedo(m)],
      confirmLabel: 'Redo',
    );
    if (!confirmed || !mounted) return;
    setState(() => _actionWorking = true);
    try {
      final result = await executeAction(m.actionJson!);
      m.actionExecuted = true;
      m.actionStatus = 'accepted';
      m.actionResult = null;
      m.undoSnapshot = result.undo;
      // Kunci perbaikan: reset flag undo agar kartu kembali menampilkan
      // tombol Undo (bukan Redo/"Di-undo").
      m.actionUndone = false;
      if (result.formId != null) {
        m.actionFormId = result.formId;
        // Form yang di-redo kembali menjadi konteks aktif sesi.
        _activeFormId = result.formId;
      }
      // Redo selesai → actionUndone false, kartu kembali menampilkan Undo.
      if (mounted) showAuthToast(context, 'Perubahan AI diterapkan kembali');
    } catch (e) {
      if (mounted) {
        showAuthToast(
          context,
          'Gagal redo: ${AuthService.errorMessage(e)}',
          isError: true,
        );
      }
    }
    if (!mounted) return;
    setState(() => _actionWorking = false);
    await persistCurrent();
  }

  /// Deskripsi satu baris untuk redo satu aksi (dipakai dialog konfirmasi) —
  /// menjelaskan perubahan maju yang akan diterapkan ulang.
  String _describeRedo(ChatMessage m) {
    final a = m.actionJson!;
    final formId = a['formId'];
    switch (a['action']) {
      case 'create_form':
        final title = a['title'] as String?;
        return 'Buat ulang form${title != null ? ' "$title"' : ''} beserta isinya (form id baru)';
      case 'add_questions':
        final n = (a['questions'] as List<dynamic>?)?.length ?? 0;
        return 'Tambahkan kembali $n soal ke form #$formId';
      case 'edit_questions':
        final n = (a['questions'] as List<dynamic>?)?.length ?? 0;
        return 'Terapkan kembali perubahan pada $n soal di form #$formId';
      case 'delete_questions':
        final n = (a['questionIds'] as List<dynamic>?)?.length ?? 0;
        return 'Hapus kembali $n soal dari form #$formId';
      case 'update_settings':
        return 'Terapkan kembali pengaturan form #$formId';
      default:
        return 'Jalankan ulang aksi ${a['action']}';
    }
  }

  /// Terapkan undo untuk satu aksi sesuai tipenya (lihat
  /// ChatMessage.undoSnapshot untuk format datanya).
  Future<void> _applyUndo(ChatMessage m) async {
    final undo = m.undoSnapshot!;
    final formId = undo['formId'] as int?;
    switch (undo['type'] as String) {
      case 'create_form':
        // Aturan: form yang sudah dikerjakan (punya respons) tidak boleh
        // di-undo — hanya rollback chat yang boleh.
        FormData? form;
        for (final f in await FormService.getMyForms()) {
          if (f.id == formId) {
            form = f;
            break;
          }
        }
        if (form != null && form.responseCount > 0) {
          throw Exception(
              'Form sudah punya ${form.responseCount} respons sehingga tidak bisa di-undo');
        }
        await FormService.deleteForm(formId!);
      case 'add_questions':
        // Hapus persis soal yang barusan dibuat AI.
        for (final raw in (undo['createdIds'] as List<dynamic>? ?? [])) {
          await FormService.deleteQuestion(formId!, raw as int);
        }
      case 'edit_questions':
        // Kembalikan isi asli soal yang diedit AI. Fetch ulang daftar
        // terkini lalu patch per id — soal buatan user manual tetap utuh.
        final originals = {
          for (final raw in (undo['originalQuestions'] as List<dynamic>? ?? []))
            (raw as Map<String, dynamic>)['id'] as int:
                Map<String, dynamic>.from(raw),
        };
        final current = await FormService.getQuestions(formId!);
        final payload = [
          for (final q in current) originals[q.id] ?? _questionToSaveJson(q),
        ];
        await FormService.updateQuestions(formId, payload);
      case 'delete_questions':
        // Ciptakan ulang soal yang dihapus AI (tanpa id → server beri id baru).
        final recreated = [
          for (final raw in (undo['deletedQuestions'] as List<dynamic>? ?? []))
            () {
              final c = Map<String, dynamic>.from(raw as Map<String, dynamic>);
              c.remove('id');
              return c;
            }(),
        ];
        if (recreated.isNotEmpty) {
          // Catat id yang ADA SEKARANG lalu bandingkan dengan hasil simpan
          // untuk mengetahui id baru milik soal yang dipulihkan — penting
          // agar redo (eksekusi ulang actionJson) menghapus id yang benar.
          final beforeIds = {
            for (final q in await FormService.getQuestions(formId!)) q.id,
          };
          final saved = await FormService.updateQuestions(formId, recreated);
          final newIds = [
            for (final q in saved)
              if (q['id'] is int && !beforeIds.contains(q['id']))
                q['id'] as int,
          ];
          m.actionJson = {
            ...?m.actionJson,
            'questionIds': newIds,
          };
        }
      case 'update_settings':
        await FormService.updateSettings(
          formId!,
          Map<String, dynamic>.from(undo['previousSettings'] as Map),
        );
      default:
        throw Exception('Tipe undo tidak dikenal: ${undo['type']}');
    }
  }

  /// Deskripsi satu baris untuk undo satu aksi (dipakai dialog konfirmasi).
  String _describeUndo(ChatMessage m) {
    final undo = m.undoSnapshot!;
    final formId = undo['formId'];
    switch (undo['type'] as String) {
      case 'create_form':
        final title = m.actionJson?['title'] as String?;
        return 'Hapus form yang dibuat AI${title != null ? ' "$title"' : ''} (form #$formId)';
      case 'add_questions':
        final n = (undo['createdIds'] as List<dynamic>?)?.length ?? 0;
        return 'Hapus $n soal yang ditambahkan AI ke form #$formId';
      case 'edit_questions':
        final n = (undo['originalQuestions'] as List<dynamic>?)?.length ?? 0;
        return 'Kembalikan $n soal ke isi sebelumnya di form #$formId';
      case 'delete_questions':
        final n = (undo['deletedQuestions'] as List<dynamic>?)?.length ?? 0;
        return 'Ciptakan ulang $n soal yang dihapus AI di form #$formId';
      case 'update_settings':
        return 'Kembalikan pengaturan form #$formId ke semula';
      default:
        return 'Batalkan aksi ${undo['type']}';
    }
  }

  /// Rincian semua perubahan yang akan di-undo mulai [fromIndex] sampai
  /// akhir chat (aksi yang sudah pernah di-undo tidak disebut lagi).
  List<String> _pendingUndoSummary(int fromIndex) {
    if (fromIndex < 0 || fromIndex >= _messages.length) return const [];
    return [
      for (final m in _messages.sublist(fromIndex))
        if (m.actionExecuted && !m.actionUndone && m.undoSnapshot != null)
          _describeUndo(m),
    ];
  }

  /// Dialog konfirmasi generik dengan rincian perubahan undo.
  Future<bool> _confirmUndoDialog({
    required String title,
    required String message,
    required List<String> changes,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 10),
                if (changes.isNotEmpty) ...[
                  const Text(
                    'Perubahan yang akan di-undo:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  for (final c in changes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ', style: TextStyle(fontSize: 11.5)),
                          Expanded(
                            child: Text(c,
                                style: const TextStyle(fontSize: 11.5)),
                          ),
                        ],
                      ),
                    ),
                ] else
                  const Text(
                    'Tidak ada perubahan form yang perlu di-undo.',
                    style: TextStyle(fontSize: 11.5, color: Colors.black54),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Catatan: perubahan yang kamu buat manual di form builder tidak ikut di-undo.',
                  style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.black45),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAuthPrimary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Auto-undo: kembalikan semua aksi AI yang diterima & belum di-undo
  /// mulai [fromIndex] sampai akhir chat (urutan terbaru dulu supaya
  /// urutan perubahan terbalik dengan benar). Best-effort — yang gagal
  /// (mis. form sudah punya respons) dilewati, jumlahnya dikembalikan.
  Future<int> _undoAcceptedActionsFrom(int fromIndex) async {
    if (fromIndex < 0 || fromIndex >= _messages.length) return 0;
    final targets = _messages.sublist(fromIndex).reversed
        .where((m) =>
            m.actionExecuted && !m.actionUndone && m.undoSnapshot != null)
        .toList();
    var failed = 0;
    for (final m in targets) {
      try {
        await _applyUndo(m);
        m.actionUndone = true;
      } catch (_) {
        failed++;
      }
    }
    return failed;
  }

  /// Tombol "coba lagi" di bawah pesanku: potong chat setelah pesan ini,
  /// undo perubahan form-nya (setelah konfirmasi), lalu kirim ulang prompt
  /// yang sama.
  Future<void> retryUserMessage(ChatMessage m) async {
    if (_streaming) {
      showAuthToast(context, 'Tunggu respons AI selesai dulu', isError: true);
      return;
    }
    final index = _messages.indexOf(m);
    if (index == -1) return;
    final confirmed = await _confirmUndoDialog(
      title: 'Coba lagi prompt ini?',
      message:
          'Semua chat setelah pesan ini akan dihapus, lalu prompt yang sama dikirim ulang ke AI.',
      changes: _pendingUndoSummary(index),
      confirmLabel: 'Coba Lagi',
    );
    if (!confirmed || !mounted) return;
    final failed = await _undoAcceptedActionsFrom(index);
    setState(() => _messages.removeRange(index, _messages.length));
    await persistCurrent();
    if (mounted && failed > 0) {
      showAuthToast(
        context,
        '$failed perubahan tidak bisa di-undo (form punya respons)',
        isError: true,
      );
    }
    await sendWithText(m.text);
  }

  /// Tombol "edit" di bawah pesanku: dialog edit + rincian undo; setelah
  /// disimpan → chat setelahnya dihapus, perubahan di-undo, lalu prompt
  /// yang sudah diedit dikirim ulang otomatis.
  Future<void> showEditMessageDialog(ChatMessage m) async {
    if (_streaming) {
      showAuthToast(context, 'Tunggu respons AI selesai dulu', isError: true);
      return;
    }
    final index = _messages.indexOf(m);
    if (index == -1) return;
    final changes = _pendingUndoSummary(index);
    final ctrl = TextEditingController(text: m.text);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit prompt',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  maxLines: null,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Tulis ulang prompt kamu',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Setelah disimpan: semua chat setelah pesan ini dihapus, dan:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                if (changes.isNotEmpty)
                  for (final c in changes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ', style: TextStyle(fontSize: 11.5)),
                          Expanded(
                            child: Text(c,
                                style: const TextStyle(fontSize: 11.5)),
                          ),
                        ],
                      ),
                    )
                else
                  const Text(
                    'Tidak ada perubahan form yang perlu di-undo.',
                    style: TextStyle(fontSize: 11.5, color: Colors.black54),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAuthPrimary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Edit & Kirim'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    final newText = ctrl.text.trim();
    if (newText.isEmpty) return;
    final failed = await _undoAcceptedActionsFrom(index);
    setState(() => _messages.removeRange(index, _messages.length));
    await persistCurrent();
    if (mounted && failed > 0) {
      showAuthToast(
        context,
        '$failed perubahan tidak bisa di-undo (form punya respons)',
        isError: true,
      );
    }
    await sendWithText(newText);
  }

  /// Tombol "salin" di bawah pesanku.
  Future<void> copyUserMessage(ChatMessage m) async {
    await Clipboard.setData(ClipboardData(text: m.text));
    if (mounted) showAuthToast(context, 'Prompt disalin');
  }

  /// Rollback (long-press menu): potong chat mulai pesan ini + undo
  /// perubahan form-nya — dengan dialog konfirmasi rinci terlebih dahulu.
  Future<void> rollbackToMessage(ChatMessage m) async {
    if (_streaming) {
      showAuthToast(context, 'Tunggu respons AI selesai dulu', isError: true);
      return;
    }
    final index = _messages.indexOf(m);
    if (index == -1) return;
    final confirmed = await _confirmUndoDialog(
      title: 'Rollback ke sini?',
      message: 'Pesan ini dan semua chat setelahnya akan dihapus.',
      changes: _pendingUndoSummary(index),
      confirmLabel: 'Rollback',
    );
    if (!confirmed || !mounted) return;
    final failed = await _undoAcceptedActionsFrom(index);
    setState(() => _messages.removeRange(index, _messages.length));
    await persistCurrent();
    if (mounted) {
      showAuthToast(
        context,
        failed > 0
            ? 'Chat di-rollback ($failed perubahan tidak bisa di-undo)'
            : 'Chat di-rollback',
      );
    }
  }

  /// Long-press pesanku: menu tambahan rollback (coba lagi / edit / salin
  /// sudah tersedia sebagai tombol di bawah bubble).
  Future<void> showMessageMenu(ChatMessage m) async {
    if (m.role != 'user') return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Rollback ke sini'),
              subtitle: const Text(
                  'Hapus pesan ini dan semua pesan setelahnya, lalu undo perubahan form-nya'),
              onTap: () => Navigator.pop(ctx, 'rollback'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'rollback') await rollbackToMessage(m);
  }
}
