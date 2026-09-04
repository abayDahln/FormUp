// ignore_for_file: invalid_use_of_protected_member
part of '../ai_chat_screen.dart';

/// Hasil eksekusi aksi AI: formId yang terlibat + data undo (snapshot
/// kondisi SEBELUM aksi, hanya entitas yang kena aksi — soal buatan user
/// manual tidak ikut, sehingga undo aman terhadap edit manual).
class ActionExecutionResult {
  final int? formId;
  final Map<String, dynamic>? undo;
  const ActionExecutionResult({this.formId, this.undo});
}

/// Serialisasi QuestionData ke bentuk payload save — dipakai merge
/// edit_questions dan snapshot undo (library-level agar bisa dipakai
/// di part chat_history_ops).
Map<String, dynamic> _questionToSaveJson(QuestionData q) => {
      'id': q.id,
      'typeId': q.typeId,
      'question': q.question,
      'questionOrder': q.questionOrder,
      if (q.questionImage != null) 'questionImage': q.questionImage,
      if (q.questionAudio != null) 'questionAudio': q.questionAudio,
      'isRequired': q.isRequired ?? false,
      if (q.correctAnswer != null) 'correctAnswer': q.correctAnswer,
      if (q.randomizeOptions != null) 'randomizeOptions': q.randomizeOptions,
      if (q.points != null) 'points': q.points,
      'options': [
        for (final o in q.options)
          {'optionText': o.optionText, 'isCorrect': o.isCorrect ?? false},
      ],
    };

/// Pengiriman pesan ke AI: kirim baru, kirim ulang, eksekusi aksi form,
/// dan dialog konfirmasi aksi.
extension _AiChatMessaging on _AiChatScreenState {
  /// Kirim teks dari field input.
  Future<void> send() async {
    await sendWithText(_controller.text.trim());
  }

  /// Hentikan respons AI yang sedang streaming (tombol stop di input bar).
  /// Teks yang sudah terketik di layar tetap disimpan sebagai bubble.
  Future<void> stopGeneration() async {
    if (!_streaming) return;
    // Ambil pesan aktif DULU lalu nolkan referensi state — callback
    // onDone/onError yang telat akan berhenti sendiri karena
    // `botMsg != _streamingMsg`.
    final msg = _streamingMsg;
    final typed = _typingStream?.shownText ?? _streamingBuffer?.toString() ?? '';
    _typingStream?.dispose();
    _typingStream = null;
    _streamingMsg = null;
    _streamingBuffer = null;
    _activeCancel?.cancel(); // abort koneksi HTTP yang menggantung
    _activeCancel = null;
    // PENTING: jangan `await _sub?.cancel()`. Untuk stream async*, cancel
    // baru selesai setelah generator mencapai titik await berikutnya —
    // bisa menggantung sampai request timeout, membuat tombol stop
    // tampak "mati". Cukup jadwalkan pembatalannya.
    unawaited(_sub?.cancel());
    _sub = null;
    if (msg != null) {
      if (typed.trim().isEmpty) {
        msg.text = 'Respons dihentikan.';
      } else {
        msg.text = typed;
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

  /// Jalankan aksi form dari AI. Mengembalikan formId yang terlibat
  /// (form baru untuk create_form, form target untuk aksi lain) + data
  /// undo (snapshot kondisi sebelum aksi) untuk tombol Undo & rollback.
  Future<ActionExecutionResult> executeAction(Map<String, dynamic> action) async {
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
          // Undo create_form = hapus seluruh form (dicek dulu: form yang
          // sudah punya respons tidak boleh dihapus).
          return ActionExecutionResult(
            formId: formId,
            undo: {'type': 'create_form', 'formId': formId},
          );
        case 'add_questions':
          final formId = action['formId'] as int?;
          if (formId == null) throw Exception('formId diperlukan');
          final questions = (action['questions'] as List<dynamic>?) ?? [];
          final payload = questions
              .map((q) => Map<String, dynamic>.from(q as Map))
              .toList();
          final created = await FormService.saveQuestions(formId, payload);
          // Undo = hapus soal yang barusan dibuat AI (id dari respons server).
          final createdIds = [
            for (final q in created)
              if (q['id'] is int) q['id'] as int,
          ];
          return ActionExecutionResult(
            formId: formId,
            undo: {
              'type': 'add_questions',
              'formId': formId,
              'createdIds': createdIds,
            },
          );
        case 'edit_questions':
          final formId = action['formId'] as int?;
          if (formId == null) throw Exception('formId diperlukan');
          final edits = (action['questions'] as List<dynamic>?) ?? [];
          if (edits.isEmpty) throw Exception('Daftar questions kosong');
          final editById = <int, Map<String, dynamic>>{};
          for (final raw in edits) {
            final e = Map<String, dynamic>.from(raw as Map);
            final id = e['id'] is int ? e['id'] as int : int.tryParse('${e['id']}');
            if (id == null) throw Exception('Setiap soal wajib punya "id"');
            editById[id] = e;
          }
          // PENTING: endpoint PUT bersifat replace-all — soal yang tidak
          // ikut dikirim IKUT TERHAPUS. Karena itu merge: soal yang tidak
          // disentuh AI dikirim ulang utuh, yang disentuh digabung
          // (nilai AI menang, field yang tak disebut dipertahankan).
          final current = await FormService.getQuestions(formId);
          // Snapshot ISI ASLI soal yang diedit — bahan untuk undo.
          final originalQuestions = [
            for (final q in current)
              if (editById.containsKey(q.id)) _questionToSaveJson(q),
          ];
          final payload = <Map<String, dynamic>>[];
          for (final q in current) {
            final e = editById.remove(q.id);
            if (e == null) {
              payload.add(_questionToSaveJson(q));
              continue;
            }
            final optsRaw = e['options'] as List<dynamic>?;
            payload.add({
              'id': q.id,
              'typeId': (e['typeId'] as int?) ?? q.typeId,
              'question': (e['question'] as String?) ?? q.question,
              'questionOrder': (e['questionOrder'] as int?) ?? q.questionOrder,
              if (q.questionImage != null) 'questionImage': q.questionImage,
              if (q.questionAudio != null) 'questionAudio': q.questionAudio,
              'isRequired': (e['isRequired'] as bool?) ?? (q.isRequired ?? false),
              if ((e['correctAnswer'] ?? q.correctAnswer) != null)
                'correctAnswer': e['correctAnswer'] ?? q.correctAnswer,
              if ((e['randomizeOptions'] ?? q.randomizeOptions) != null)
                'randomizeOptions': e['randomizeOptions'] ?? q.randomizeOptions,
              if ((e['points'] ?? q.points) != null)
                'points': e['points'] ?? q.points,
              'options': optsRaw == null
                  ? [
                      for (final o in q.options)
                        {
                          'optionText': o.optionText,
                          'isCorrect': o.isCorrect ?? false,
                        },
                    ]
                  : [
                      for (final o in optsRaw)
                        o is String
                            ? {'optionText': o}
                            : Map<String, dynamic>.from(o as Map),
                    ],
            });
          }
          // Ada id dari AI yang tidak cocok dengan soal manapun → gagal
          // jelas, jangan diam-diam dilewati (user bisa kira sudah diedit).
          if (editById.isNotEmpty) {
            throw Exception(
                'Soal dengan id ${editById.keys.join(', ')} tidak ditemukan di form ini');
          }
          await FormService.updateQuestions(formId, payload);
          return ActionExecutionResult(
            formId: formId,
            undo: {
              'type': 'edit_questions',
              'formId': formId,
              'originalQuestions': originalQuestions,
            },
          );
        case 'delete_questions':
          final formId = action['formId'] as int?;
          if (formId == null) throw Exception('formId diperlukan');
          final ids = ((action['questionIds'] as List<dynamic>?) ?? [])
              .map((v) => v is int ? v : int.tryParse('$v'))
              .whereType<int>()
              .toSet()
              .toList();
          if (ids.isEmpty) throw Exception('questionIds diperlukan');
          // Snapshot isi soal yang akan dihapus — undo bisa menciptakan
          // ulang soal-soal ini persis seperti semula.
          final current = await FormService.getQuestions(formId);
          final deletedQuestions = [
            for (final q in current)
              if (ids.contains(q.id)) _questionToSaveJson(q),
          ];
          for (final id in ids) {
            await FormService.deleteQuestion(formId, id);
          }
          return ActionExecutionResult(
            formId: formId,
            undo: {
              'type': 'delete_questions',
              'formId': formId,
              'deletedQuestions': deletedQuestions,
            },
          );
        case 'update_settings':
          final formId = action['formId'] as int?;
          if (formId == null) throw Exception('formId diperlukan');
          final settings = Map<String, dynamic>.from(
            action['settings'] as Map? ?? {},
          );
          // Snapshot pengaturan lama — undo mengembalikan persis semula.
          final prevForm = await FormService.getForm(formId);
          final previousSettings = Map<String, dynamic>.from(
            prevForm['settings'] as Map? ?? {},
          );
          await FormService.updateSettings(formId, settings);
          return ActionExecutionResult(
            formId: formId,
            undo: {
              'type': 'update_settings',
              'formId': formId,
              'previousSettings': previousSettings,
            },
          );
        default:
          throw Exception('Aksi tidak dikenal: $act');
      }
    } catch (e) {
      throw Exception(AuthService.errorMessage(e));
    }
  }

  /// Pesan dengan aksi form yang belum diterima/ditolak di session aktif
  /// (yang terakhir, bila ada lebih dari satu).
  ChatMessage? get pendingActionMessage {
    for (final m in _messages.reversed) {
      if (m.hasPendingAction) return m;
    }
    return null;
  }

  /// Terima aksi pending dari bar di atas field prompt: jalankan aksi form.
  /// Gagal → status tetap pending (bisa coba lagi atau tolak).
  Future<void> acceptPendingAction() async {
    final m = pendingActionMessage;
    if (m == null || _actionWorking) return;
    setState(() => _actionWorking = true);
    try {
      final result = await executeAction(m.actionJson!);
      m.actionExecuted = true;
      m.actionStatus = 'accepted';
      m.actionResult = null;
      m.actionFormId = result.formId;
      m.undoSnapshot = result.undo;
      // Form yang baru dibuat/diedit AI menjadi form aktif sesi — pesan
      // lanjutan otomatis memakai konteksnya tanpa perlu mention.
      if (result.formId != null) _activeFormId = result.formId;
      if (mounted) showAuthToast(context, 'Perubahan berhasil diterapkan');
    } catch (e) {
      m.actionResult = 'Gagal: $e';
      if (mounted) {
        showAuthToast(context, 'Gagal menjalankan aksi: $e', isError: true);
      }
    }
    if (!mounted) return;
    setState(() => _actionWorking = false);
    await persistCurrent();
  }

  /// Tolak aksi pending dari bar di atas field prompt.
  Future<void> rejectPendingAction() async {
    final m = pendingActionMessage;
    if (m == null || _actionWorking) return;
    setState(() {
      _actionWorking = false;
      m.actionStatus = 'rejected';
      m.actionResult = null;
    });
    if (mounted) showAuthToast(context, 'Perubahan ditolak');
    await persistCurrent();
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
        // Cache konteks form untuk pesan lanjutan di sesi ini (mis. user
        // lanjut "edit soal sebelumnya" tanpa mention lagi) — ikut persist.
        _lastFormContext = extraContext;
        // Mention = user eksplisit memilih form → jadi form aktif sesi.
        _activeFormId = mentionIds.first;
      } catch (_) {}
    } else if (rawText.toLowerCase().contains('form saya') ||
        rawText.toLowerCase().contains('list form') ||
        rawText.toLowerCase().contains('daftar form')) {
      try {
        extraContext = await AiFormContextService.buildAllFormsSummary();
      } catch (_) {}
    } else if (_activeFormId != null) {
      // Pesan lanjutan di sesi yang sedang membahas sebuah form (dibuat AI
      // atau pernah di-mention): bangun konteks SEGAR dari form aktif agar
      // id soal selalu terkini — tanpa perlu user mention ulang.
      try {
        extraContext = await AiFormContextService.buildContext([_activeFormId!]);
        _lastFormContext = extraContext;
      } catch (_) {
        extraContext = _lastFormContext; // fallback ke cache terakhir
      }
    } else if (_lastFormContext != null && _lastFormContext!.isNotEmpty) {
      // Fallback terakhir: konteks cache tanpa form aktif yang diketahui.
      extraContext = _lastFormContext;
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
    // Notifier live: chunk ditulis ke sini TANPA setState, sehingga hanya
    // bubble ini yang rebuild (via ValueListenableBuilder).
    botMsg.stream = ValueNotifier<String>('');
    setState(() {
      _messages.add(botMsg);
      _streaming = true;
      _streamingMsg = botMsg;
      _streamingBuffer = buffer;
    });
    // Pastikan posisi sudah di dasar saat indikator "AI mengetik..." muncul,
    // sehingga auto-follow saat streaming aktif (syaratnya _isAtBottom).
    _scrollToBottom(immediate: true);

    // Batalkan stream sebelumnya bila masih hidup (anti tumpuk listener).
    // Jangan await — cancel async* stream bisa menggantung (lihat
    // stopGeneration); request lama di-abort lewat token-nya masing-masing.
    unawaited(_sub?.cancel());
    _sub = null;

    // Mesin ketik & cancel token dibuat PER ATTEMPT (notifier bubble sama),
    // karena auto-retry membuat stream baru dengan engine baru.
    TypingStream? typing;
    GeminiCancel? cancelToken;

    /// (Re)mulai stream ke bubble yang sama. Attempt kedua = auto-retry
    /// internal: kondisi transien (mis. attempt pertama selesai tanpa teks)
    /// hampir selalu sembuh dengan percobaan ulang — sama seperti tombol
    /// "Coba lagi" yang terbukti berhasil, hanya otomatis.
    void subscribe({required bool isRetry}) {
      typing?.dispose();
      typing = TypingStream(
        botMsg.stream!,
        onTick: () {
          // Magnet auto-scroll: ikuti hanya bila user memang di dasar —
          // kalau user scroll ke atas sendiri, magnet lepas sampai user
          // kembali ke dasar.
          if (_isAtBottom) _followStream();
          // Konten bertambah tanpa event scroll → update visibilitas FAB
          // agar muncul saat user jauh di atas dan respons terus mengalir.
          _onScroll();
        },
      );
      _typingStream = typing;
      cancelToken = GeminiCancel();
      _activeCancel = cancelToken;
      // **1. Stream-Based API Handling:** SSE/chunked dari endpoint
      // streamGenerateContent?alt=sse diparse per-baris `data:` di
      // GeminiService.streamChat dan di-yield per token/chunk.
      _sub = GeminiService.streamChat(history, cancel: cancelToken).listen(
        (chunk) {
          // **2. Smooth rendering:** append ke buffer; tampilan per kata
          // diserahkan ke TypingStream (lihat onTick untuk auto-scroll).
          buffer.write(chunk);
          typing?.add(chunk);
        },
        onDone: () async {
          // Stream sudah dihentikan user (stop) — biarkan stopGeneration
          // yang memfinalisasi bubble ini.
          if (botMsg != _streamingMsg) return;
          // Biarkan ketikan mengejar sisa teks dulu (maksimal 8 detik
          // pengaman), lalu finalisasi.
          try {
            await typing?.finish().timeout(const Duration(seconds: 8));
          } catch (_) {}
          typing?.dispose();
          if (botMsg != _streamingMsg) return;
          final full = buffer.toString();
          // Stream selesai TANPA teks → auto-retry SEKALI dulu; kalau masih
          // kosong juga, tampilkan pesan error yang jelas.
          if (full.trim().isEmpty) {
            if (!isRetry) {
              debugPrint('[AiChat] Stream selesai kosong — auto-retry sekali');
              subscribe(isRetry: true);
              return;
            }
            botMsg.text = 'AI menyelesaikan respons tanpa mengirim teks. '
                'Ketuk "Coba lagi" untuk mengulang; jika terus terjadi, '
                'coba mulai chat baru.';
            botMsg.isError = true;
          } else {
            botMsg.text = full;
          }
          botMsg.disposeStream();
          if (!mounted) return;
          _typingStream?.dispose();
          _typingStream = null;
          _streamingMsg = null;
          _streamingBuffer = null;
          setState(() => _streaming = false);
          await persistCurrent();
          // Aksi form (buat/edit): TIDAK pakai dialog. Aksi disimpan sebagai
          // "pending" di pesan — ikut persist ke session, dan tombol
          // Terima/Tolak tampil di ATAS field prompt (PendingActionBar).
          final action = extractActionJson(botMsg.text);
          if (action != null) {
            botMsg.actionJson = action;
            botMsg.actionStatus = 'pending';
            botMsg.actionResult = null;
            if (!mounted) return;
            setState(() {});
            showAuthToast(
              context,
              'AI mengajukan perubahan form — terima atau tolak di bawah',
            );
          }
          await persistCurrent();
        },
        onError: (e) async {
          // Stream sudah dihentikan user (stop) — biarkan stopGeneration
          // yang memfinalisasi bubble ini.
          if (botMsg != _streamingMsg) return;
          final partial = buffer.toString();
          if (partial.trim().isNotEmpty) {
            // Stream putus di tengah tapi sudah ada jawaban parsial:
            // tampilkan parsial + catatan, JANGAN fallback (menghemat
            // waktu tunggu — user sudah menunggu sekali).
            botMsg.text = '$partial\n\n— Respons terputus di tengah jalan '
                '(koneksi tidak stabil). Ketuk "Coba lagi" untuk jawaban baru.';
            botMsg.isError = true;
            botMsg.disposeStream();
            if (!mounted) return;
            _typingStream?.dispose();
            _typingStream = null;
            _streamingMsg = null;
            _streamingBuffer = null;
            setState(() => _streaming = false);
            await persistCurrent();
            return;
          }
          if (cancelToken?.isCancelled ?? false) return;
          // GEMINI_NO_TEXT = token habis untuk thinking internal ATAU
          // kondisi transien stream kosong. Auto-retry sekali dulu —
          // attempt ulang sering normal; fallback generateOnce hanya akan
          // mengulang penyebab yang sama.
          if (e.toString().contains('GEMINI_NO_TEXT')) {
            if (!isRetry) {
              debugPrint('[AiChat] GEMINI_NO_TEXT — auto-retry sekali');
              subscribe(isRetry: true);
              return;
            }
            botMsg.text = GeminiService.friendlyMessage(e);
            botMsg.isError = true;
            botMsg.disposeStream();
            if (!mounted) return;
            _typingStream?.dispose();
            _typingStream = null;
            _streamingMsg = null;
            _streamingBuffer = null;
            setState(() => _streaming = false);
            await persistCurrent();
            return;
          }
          // Tidak ada data sama sekali — coba sekali via endpoint
          // non-stream (timeout 30 detik, bisa di-stop juga).
          try {
            final full = await GeminiService.generateOnce(
              history,
              cancel: cancelToken,
            );
            if (botMsg != _streamingMsg) return; // di-stop saat fallback jalan
            if (full.trim().isEmpty) {
              botMsg.text =
                  'AI tidak mengirim jawaban (respons kosong dari server). '
                  'Ketuk "Coba lagi" untuk mengulang.';
              botMsg.isError = true;
            } else {
              botMsg.text = full;
            }
            botMsg.disposeStream();
            if (!mounted) return;
            _typingStream?.dispose();
            _typingStream = null;
            _streamingMsg = null;
            _streamingBuffer = null;
            setState(() => _streaming = false);
            await persistCurrent();
          } catch (e2) {
            if (botMsg != _streamingMsg) return; // di-stop saat fallback jalan
            botMsg.text = GeminiService.friendlyMessage(e2);
            botMsg.isError = true;
            botMsg.disposeStream();
            if (!mounted) return;
            _typingStream?.dispose();
            _typingStream = null;
            _streamingMsg = null;
            _streamingBuffer = null;
            setState(() => _streaming = false);
            await persistCurrent();
          }
        },
        cancelOnError: false,
      );
    }

    subscribe(isRetry: false);
  }
}
