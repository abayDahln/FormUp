// ignore_for_file: invalid_use_of_protected_member
part of '../ai_chat_screen.dart';

/// Pengiriman pesan ke AI: kirim baru, kirim ulang, eksekusi aksi form,
/// dan dialog konfirmasi aksi.
extension _AiChatMessaging on _AiChatScreenState {
  /// Kirim teks dari field input.
  Future<void> send() async {
    await sendWithText(_controller.text.trim());
  }

  /// Hentikan respons AI yang sedang streaming (tombol stop di input bar).
  /// Partial text yang sudah diterima tetap disimpan sebagai bubble.
  Future<void> stopGeneration() async {
    if (!_streaming) return;
    await _sub?.cancel();
    _sub = null;
    final msg = _streamingMsg;
    final buffer = _streamingBuffer;
    _streamingMsg = null;
    _streamingBuffer = null;
    if (msg != null) {
      final partial = buffer?.toString() ?? '';
      if (partial.trim().isEmpty) {
        msg.text = 'Respons dihentikan.';
      } else {
        msg.text = partial;
      }
      msg.disposeStream();
    }
    if (!mounted) return;
    setState(() => _streaming = false);
    await persistCurrent();
  }

  /// Kirim ulang pesan user terakhir setelah bubble error (tombol "Coba lagi").
  /// Bubble error dibuang dulu agar tidak menumpuk, lalu pesan dikirim ulang.
  Future<void> retryMessage(ChatMessage failed) async {
    if (_streaming) return;
    final idx = _messages.indexOf(failed);
    String? lastUser;
    for (var i = idx - 1; i >= 0; i--) {
      if (_messages[i].role == 'user') {
        lastUser = _messages[i].text;
        break;
      }
    }
    if (lastUser == null || lastUser.trim().isEmpty) return;
    setState(() {
      failed.disposeStream();
      _messages.remove(failed);
    });
    await persistCurrent();
    await sendWithText(lastUser);
  }

  Map<String, dynamic>? extractActionJson(String text) {
    final fence = RegExp(r'```json\s*([\s\S]*?)\s*```', caseSensitive: false);
    final m = fence.firstMatch(text);
    String? candidate;
    if (m != null) candidate = m.group(1);
    if (candidate == null) {
      final brace = RegExp(r'\{[\s\S]*"action"[\s\S]*\}');
      final m2 = brace.firstMatch(text);
      if (m2 != null) candidate = m2.group(0);
    }
    if (candidate == null) return null;
    try {
      final j = jsonDecode(candidate) as Map<String, dynamic>;
      if (j.containsKey('action')) return j;
    } catch (_) {}
    return null;
  }

  Future<void> executeAction(Map<String, dynamic> action) async {
    final act = action['action'] as String?;
    try {
      switch (act) {
        case 'create_form':
          final title = action['title'] as String? ?? 'Form AI';
          final description = action['description'] as String?;
          final formId = await FormService.createForm(
            title: title,
            description: description,
          );
          final questions = (action['questions'] as List<dynamic>?) ?? [];
          if (questions.isNotEmpty) {
            final payload = questions.map((q) {
              final map = Map<String, dynamic>.from(q as Map);
              if (map['options'] is List) {
                map['options'] = (map['options'] as List).map((o) {
                  if (o is String) return {'optionText': o};
                  return Map<String, dynamic>.from(o as Map);
                }).toList();
              }
              return map;
            }).toList();
            await FormService.saveQuestions(formId, payload);
          }
          return;
        case 'add_questions':
          final formId = action['formId'] as int?;
          if (formId == null) throw Exception('formId diperlukan');
          final questions = (action['questions'] as List<dynamic>?) ?? [];
          final payload = questions
              .map((q) => Map<String, dynamic>.from(q as Map))
              .toList();
          await FormService.saveQuestions(formId, payload);
          return;
        case 'update_settings':
          final formId = action['formId'] as int?;
          if (formId == null) throw Exception('formId diperlukan');
          final settings = Map<String, dynamic>.from(
            action['settings'] as Map? ?? {},
          );
          await FormService.updateSettings(formId, settings);
          return;
        default:
          throw Exception('Aksi tidak dikenal: $act');
      }
    } catch (e) {
      throw Exception(AuthService.errorMessage(e));
    }
  }

  /// Jalankan aksi form dari kartu aksi bubble (tombol "Jalankan").
  Future<void> runBubbleAction(ChatMessage m) async {
    try {
      await executeAction(m.actionJson!);
      setState(() {
        m.actionExecuted = true;
        m.actionResult = 'Berhasil';
      });
      if (mounted) showAuthToast(context, 'Berhasil');
      await persistCurrent();
    } catch (e) {
      setState(() => m.actionResult = 'Gagal: $e');
      if (mounted) showAuthToast(context, '$e', isError: true);
    }
  }

  Future<void> sendWithText(String rawText) async {
    if (rawText.isEmpty || _streaming) return;
    if (!GeminiService.hasKey) {
      showAuthToast(context, 'GEMINI_API_KEY belum diatur', isError: true);
      showAiApiKeyDialog(
        context,
        onKeyChanged: () {
          if (mounted) setState(() {});
        },
      );
      return;
    }
    // ensure session exists
    if (_currentSessionId == null) await newSession();
    // Agent: deteksi @mention dan bangun konteks form
    final mentionIds = extractMentionIds(rawText);
    String? extraContext;
    if (mentionIds.isNotEmpty) {
      try {
        extraContext = await AiFormContextService.buildContext(mentionIds);
      } catch (_) {}
    } else if (rawText.toLowerCase().contains('form saya') ||
        rawText.toLowerCase().contains('list form') ||
        rawText.toLowerCase().contains('daftar form')) {
      try {
        extraContext = await AiFormContextService.buildAllFormsSummary();
      } catch (_) {}
    }
    final displayText = rawText;
    final sendText =
        extraContext != null && extraContext.isNotEmpty
        ? '$extraContext\n\nPertanyaan user: $rawText'
        : rawText;
    // bersihkan mention picker
    setState(() {
      _mentionCandidates = [];
      _isMentionActive = false;
      _pickedMentions.clear(); // jangan bawa mention pesan sebelumnya ke pesan berikutnya
    });

    final userMsg = ChatMessage(role: 'user', text: displayText);
    setState(() {
      _messages.add(userMsg);
      _controller.clear();
    });
    _scrollToBottom();
    await persistCurrent();

    // history yang dikirim ke AI pakai sendText untuk pesan terakhir, tapi simpan displayText
    final history = _messages.map((m) {
      if (m == userMsg && sendText != displayText) {
        return {'role': m.role, 'text': sendText};
      }
      return {'role': m.role, 'text': m.text};
    }).toList();
    final botMsg = ChatMessage(role: 'model', text: '');
    final buffer = StringBuffer();
    // Lampirkan notifier live: chunk ditulis ke sini TANPA setState,
    // sehingga hanya bubble ini yang rebuild via ValueListenableBuilder.
    botMsg.stream = ValueNotifier<String>('');
    setState(() {
      _messages.add(botMsg);
      _streaming = true;
      _streamingMsg = botMsg;
      _streamingBuffer = buffer;
    });

    // Batalkan stream sebelumnya bila masih hidup (anti tumpuk listener).
    await _sub?.cancel();
    _sub = null;
    try {
      // **1. Stream-Based API Handling:** SSE/chunked dari endpoint
      // streamGenerateContent?alt=sse diparse per-baris `data:` di
      // GeminiService.streamChat dan di-yield per token/chunk.
      _sub = GeminiService.streamChat(history).listen(
        (chunk) {
          // **2. Smooth rendering:** append ke buffer + push ke notifier.
          // ValueNotifier menggabungkan update sinkron beruntun menjadi
          // satu rebuild bubble — tanpa setState(), tanpa rebuild ListView.
          buffer.write(chunk);
          botMsg.stream?.value = buffer.toString();
          // **3. Auto-scroll bersyarat:** ikuti hanya bila user di dasar.
          if (_isAtBottom) _followStream();
        },
        onDone: () async {
          final full = buffer.toString();
          // Stream bisa selesai tanpa chunk (mis. SSE gagal diam-diam) —
          // jangan biarkan teks kosong karena bubble me-render "...".
          if (full.trim().isEmpty) {
            botMsg.text = 'Respons AI kosong. Coba kirim ulang.';
            botMsg.isError = true;
          } else {
            botMsg.text = full;
          }
          botMsg.disposeStream();
          if (!mounted) return;
          _streamingMsg = null;
          _streamingBuffer = null;
          setState(() => _streaming = false);
          await persistCurrent();
          final action = extractActionJson(botMsg.text);
          if (action != null) {
            botMsg.actionJson = action;
            setState(() {});
            if (mounted) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    'Jalankan Aksi AI?',
                    style: TextStyle(fontFamily: kFontBold, fontSize: 14),
                  ),
                  content: SingleChildScrollView(
                    child: Text(
                      jsonEncode(action),
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Jalankan'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  await executeAction(action);
                  botMsg.actionExecuted = true;
                  botMsg.actionResult = 'Berhasil dijalankan';
                  if (mounted) {
                    showAuthToast(
                      context,
                      'Aksi ${action['action']} berhasil',
                    );
                    setState(() {});
                  }
                } catch (e) {
                  botMsg.actionResult = 'Gagal: $e';
                  if (mounted) {
                    showAuthToast(
                      context,
                      'Gagal menjalankan aksi: $e',
                      isError: true,
                    );
                  }
                  setState(() {});
                }
                await persistCurrent();
              }
            }
          }
          await persistCurrent();
        },
        onError: (e) async {
          // Fallback non-stream bila SSE gagal di tengah jalan.
          try {
            final full = await GeminiService.generateOnce(history);
            if (full.trim().isEmpty) {
              botMsg.text = 'Respons AI kosong. Coba kirim ulang.';
              botMsg.isError = true;
            } else {
              botMsg.text = full;
            }
            botMsg.disposeStream();
            if (!mounted) return;
            _streamingMsg = null;
          _streamingBuffer = null;
          setState(() => _streaming = false);
            await persistCurrent();
          } catch (e2) {
            botMsg.text = GeminiService.friendlyMessage(e2);
            botMsg.isError = true;
            botMsg.disposeStream();
            if (!mounted) return;
            _streamingMsg = null;
          _streamingBuffer = null;
          setState(() => _streaming = false);
            await persistCurrent();
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      botMsg.text = GeminiService.friendlyMessage(e);
      botMsg.isError = true;
      botMsg.disposeStream();
      if (!mounted) return;
      _streamingMsg = null;
      _streamingBuffer = null;
      setState(() => _streaming = false);
      await persistCurrent();
    }
  }
}
