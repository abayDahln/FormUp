// ignore_for_file: invalid_use_of_protected_member
part of '../ai_chat_screen.dart';

/// Logika @mention form: label pendek, deteksi ketikan, pilih mention,
/// dan ekstraksi id form untuk konteks AI.
extension _AiChatMentions on _AiChatScreenState {
  Future<void> loadAllForms({bool force = false}) async {
    if (_isLoadingForms) return;
    // jika sebelumnya gagal, jangan retry terus — hanya retry saat dipaksa (ketik '@' lagi)
    if (_formsLoadFailed && !force) return;
    _isLoadingForms = true;
    _formsLoadFailed = false;
    try {
      final forms = await FormService.getMyForms();
      _formsLoadError = null;
      if (mounted) setState(() => _allForms = forms);
    } catch (e) {
      _formsLoadFailed = true;
      _formsLoadError = AuthService.errorMessage(e);
      debugPrint('[AiChat] Gagal memuat daftar form untuk mention: $e');
      if (mounted) setState(() {});
    } finally {
      _isLoadingForms = false;
      // re-evaluasi kandidat setelah forms selesai dimuat
      if (mounted && _isMentionActive) _onTextChanged();
    }
  }

  /// Label mention pendek: maksimal 2 kata pertama, lalu dipotong dengan "..."
  String mentionLabel(FormData f) {
    final words = f.title
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'form';
    var s = words.take(2).join(' ');
    if (words.length > 2) s = '$s...';
    if (s.length > 20) s = '${s.substring(0, 17)}...';
    return s;
  }

  void _onTextChanged() {
    final text = _controller.text;
    final prev = _lastText;
    _lastText = text;
    // sinkronkan token highlight
    _controller.mentionTokens = _pickedMentions.values
        .where((l) => text.contains('@$l'))
        .toList();
    // buang picked yang tokennya sudah tidak ada di teks (mis. select-all delete / cut)
    if (_pickedMentions.isNotEmpty) {
      final stale = _pickedMentions.keys
          .where((id) => !text.contains('@${_pickedMentions[id]}'))
          .toList();
      if (stale.isNotEmpty) {
        setState(() {
          for (final id in stale) {
            _pickedMentions.remove(id);
          }
        });
      }
    }

    // Backspace: jika 1 karakter dihapus dan karakter itu ada di dalam token mention,
    // hapus seluruh mention sekaligus (alasan: "@label" yang sebagian tidak bermakna)
    if (text.length == prev.length - 1 && _pickedMentions.isNotEmpty) {
      final sel = _controller.selection;
      final removedAt = sel.isValid && sel.baseOffset >= 0
          ? sel.baseOffset
          : -1;
      if (removedAt >= 0) {
        for (final entry in _pickedMentions.entries) {
          final token = '@${entry.value}';
          final idx = prev.indexOf(token);
          if (idx != -1 &&
              removedAt > idx &&
              removedAt <= idx + token.length) {
            var end = idx + token.length;
            if (end < prev.length && prev[end] == ' ') end++;
            final newText = prev.substring(0, idx) + prev.substring(end);
            setState(() {
              _pickedMentions.remove(entry.key);
              _lastText = newText;
              _controller.mentionTokens = _pickedMentions.values
                  .where((l) => newText.contains('@$l'))
                  .toList();
            });
            _controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(
                offset: idx.clamp(0, newText.length),
              ),
            );
            return;
          }
        }
      }
    }

    final sel = _controller.selection;
    if (!sel.isValid || sel.baseOffset < 0) {
      if (_isMentionActive) {
        setState(() {
          _isMentionActive = false;
          _mentionCandidates = [];
        });
      }
      return;
    }
    final cursor = sel.baseOffset;
    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');
    if (atIndex == -1) {
      if (_isMentionActive) {
        setState(() {
          _isMentionActive = false;
          _mentionCandidates = [];
        });
      }
      return;
    }
    // jika ada spasi/newline antara @ dan cursor dengan jarak > 30, anggap bukan mention
    final query = before.substring(atIndex + 1);
    if (query.contains(' ') || query.contains('\n') || query.length > 30) {
      if (_isMentionActive) {
        setState(() {
          _isMentionActive = false;
          _mentionCandidates = [];
        });
      }
      return;
    }
    // valid mention query — '@' saja tampilkan semua, '@pemrograman' filter, tooltip scrollable
    _mentionStart = atIndex;
    _mentionQuery = query.toLowerCase();
    _isMentionActive = true;
    // refresh forms jika kosong (user baru buat form) — force retry saat user mengetik '@' lagi
    if (_allForms.isEmpty && !_isLoadingForms) {
      loadAllForms(force: _formsLoadFailed);
    }
    final candidates = _allForms.where((f) {
      final t = f.title.toLowerCase();
      return _mentionQuery.isEmpty || t.contains(_mentionQuery);
    }).toList();
    setState(() => _mentionCandidates = candidates);
  }

  void selectMention(FormData form) {
    if (_mentionStart < 0 || _mentionStart >= _controller.text.length) return;
    final text = _controller.text;
    final cursor =
        _controller.selection.isValid && _controller.selection.baseOffset >= 0
        ? _controller.selection.baseOffset
        : text.length;
    final before = text.substring(0, _mentionStart);
    final after = cursor <= text.length ? text.substring(cursor) : '';
    final mention = '@${mentionLabel(form)} ';
    final newText = '$before$mention$after';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: (before + mention).length),
    );
    _lastText = newText;
    _controller.mentionTokens = [
      ..._controller.mentionTokens,
      mentionLabel(form),
    ];
    _pickedMentions[form.id] = mentionLabel(form);
    setState(() {
      _mentionCandidates = [];
      _isMentionActive = false;
    });
  }

  List<int> extractMentionIds(String text) {
    // Deteksi via picked ids yang masih ada di text (pakai label pendek), fallback scan label judul
    final ids = <int>[];
    for (final entry in _pickedMentions.entries) {
      if (text.contains('@${entry.value}')) ids.add(entry.key);
    }
    // fallback: hanya match '@label' persis, jangan judul polos (hindari konteks palsu)
    if (ids.isEmpty && text.contains('@')) {
      for (final f in _allForms) {
        if (text.contains('@${mentionLabel(f)}')) {
          ids.add(f.id);
          if (ids.length >= 3) break;
        }
      }
    }
    return ids.toSet().toList();
  }
}
