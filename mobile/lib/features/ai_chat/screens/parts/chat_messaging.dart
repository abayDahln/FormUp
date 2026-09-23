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
          {
            'optionText': o.optionText,
            'isCorrect': o.isCorrect ?? false,
            if (o.optionImage != null && o.optionImage!.isNotEmpty)
              'optionImage': o.optionImage,
          },
      ],
    };

/// Sanitasi soal AI sebelum dikirim ke server — gagal dengan pesan jelas
/// bila ada kunci ambigu (mis. PG tanpa/tepat >1 kunci), agar data rusak
/// tidak pernah tersimpan.
List<Map<String, dynamic>> _sanitizedAiQuestions(List<dynamic> raw) {
  final r = sanitizeAiQuestions(raw);
  if (r.hasErrors) {
    throw Exception(
      'Kunci jawaban AI bermasalah:\n${r.errors.join('\n')}\nMinta AI perbaiki (mis. "beri tepat 1 kunci jawaban per soal").',
    );
  }
  return r.questions;
}

/// Sanitasi sebagian edit AI (edit_questions) memakai tipe efektif.
/// Opsi existing dipakai sebagai dasar bila AI tidak menyertakan opsi —
/// sehingga kunci baru tetap dicocokkan ke flag yang konsisten.
/// Melempar dengan pesan jelas bila ambigu (caller menggagalkan aksi).
void _sanitizeAiEdit(
  Map<String, dynamic> e,
  int existingTypeId,
  QuestionData existing,
) {
  final effType =
      e['typeId'] is num ? (e['typeId'] as num).toInt() : existingTypeId;
  if (effType != 2 && effType != 3 && effType != 5) return;
  final touchesOptions = e['options'] is List;
  final touchesKey = e.containsKey('correctAnswer');
  if (!touchesOptions && !touchesKey) return;
  final r = sanitizeAiQuestions([
    {
      'typeId': effType,
      'question': e['question'] ?? existing.question,
      'isRequired': e['isRequired'] ?? existing.isRequired ?? false,
      'points': e.containsKey('points') ? e['points'] : existing.points,
      'correctAnswer': touchesKey ? e['correctAnswer'] : existing.correctAnswer,
      // Kunci baru tanpa opsi baru → cocokkan ke opsi existing.
      'options': touchesOptions
          ? e['options']
          : [
              for (final o in existing.options)
                {'optionText': o.optionText, 'isCorrect': o.isCorrect ?? false},
            ],
    }
  ]);
  if (r.hasErrors) {
    throw Exception(
      'Kunci jawaban AI bermasalah:\n${r.errors.join('\n')}\nMinta AI perbaiki (mis. "beri tepat 1 kunci jawaban per soal").',
    );
  }
  final clean = r.questions.first;
  if (effType == 2 || effType == 3) {
    // Tulis balik flag yang sudah dikonsistensikan (mencegah kunci teks
    // vs flag opsi tidak sinkron).
    e['options'] = clean['options'];
    if (touchesKey) e['correctAnswer'] = clean['correctAnswer'];
  } else if (touchesKey) {
    e['correctAnswer'] = clean['correctAnswer'];
  }
  if (e.containsKey('points')) e['points'] = clean['points'];
}

/// Pengiriman pesan ke AI: kirim baru, kirim ulang, eksekusi aksi form,
/// dan dialog konfirmasi aksi.
extension _AiChatMessaging on _AiChatScreenState {
  /// Kirim teks dari field input (plus lampiran pending).
  /// Kirim teks dari field input (plus lampiran pending).
  Future<void> send() async {
    await sendWithText(_controller.text.trim(), pendingAttachments: List<AiAttachment>.from(_pendingAttachments));
  }

  /// Hentikan respons AI yang sedang streaming (tombol stop di input bar).
  /// Teks yang sudah terketik di layar tetap disimpan sebagai bubble.
  Future<void> stopGeneration() async {
    _dismissKeyboard();
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

  /// Kirim ulang dari bubble error (tombol "Coba lagi"): SAMA seperti
  /// retry prompt — hapus prompt sebelumnya beserta bubble error, lalu
  /// kirim ulang (jangan jadi pesan duplikat).
  Future<void> retryMessage(ChatMessage failed) async {
    _dismissKeyboard();
    if (_streaming || _sending) return;
    final idx = _messages.indexOf(failed);
    ChatMessage? lastUser;
    for (var i = idx - 1; i >= 0; i--) {
      if (_messages[i].role == 'user') {
        lastUser = _messages[i];
        break;
      }
    }
    if (lastUser == null || lastUser.text.trim().isEmpty) {
      if (mounted) {
        showAuthToast(context, 'Prompt tidak ditemukan', isError: true);
      }
      return;
    }
    failed.disposeStream();
    await retryUserMessage(lastUser);
  }

  /// True bila teks tampak seperti JSON aksi yang tak selesai (pagar
  /// ```json tak tertutup / ada penanda "action" tapi gagal parse).
  /// [strict] = hanya bila finishReason MAX_TOKENS/LENGTH (jalur normal);
  /// non-strict untuk potongan akibat koneksi putus (watchdog 40 dtk).
  bool _isTruncatedResponse(String text, {bool strict = true}) {
    final hasUnclosedFence = hasUnclosedJsonFence(text);
    final hasActionMarker = RegExp(r'"action"\s*:').hasMatch(text);
    if (!hasUnclosedFence && !hasActionMarker) return false;
    if (!strict) return true;
    final finish = GeminiService.lastFinishReason;
    return finish == 'MAX_TOKENS' || finish == 'LENGTH';
  }

  /// Finalisasi aksi setelah teks final tersedia — dipakai jalur stream
  /// maupun fallback non-stream: parse JSON → pending + toast, atau tandai
  /// terpotong (notice + tombol Lanjutkan) bila MAX_TOKENS.
  Future<void> _finalizeAction(ChatMessage botMsg,
      {bool allowUnknownFinish = false}) async {
    final action = parseActionJson(botMsg.text);
    if (action != null) {
      botMsg.actionJson = action;
      botMsg.actionStatus = 'pending';
      botMsg.actionResult = null;
      botMsg.isTruncated = false;
      if (!mounted) return;
      setState(() {});
      showAuthToast(
        context,
        'AI mengajukan perubahan form — terima atau tolak di bawah',
      );
    } else if (_isTruncatedResponse(botMsg.text,
        strict: !allowUnknownFinish)) {
      botMsg.isTruncated = true;
      if (!mounted) return;
      setState(() {});
      showAuthToast(
        context,
        'Respons AI terpotong — ketuk Lanjutkan di bubble',
        isError: true,
      );
    }
    await persistCurrent();
  }

  /// Lanjutkan respons terpotong: minta AI tulis ulang SELURUH jawaban +
  /// SATU blok JSON aksi yang lengkap dalam satu respons. Lampiran pesan
  /// user terakhir ikut disertakan lagi agar AI tetap "melihat" file-nya
  /// (history ke AI hanya menempelkan file pada pesan terakhir).
  Future<void> continueTruncated(ChatMessage m) async {
    if (_streaming || _sending) return;
    _dismissKeyboard();
    m.isTruncated = false;
    if (mounted) setState(() {});
    await persistCurrent();
    List<AiAttachment>? resendAtts;
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == 'user' && _messages[i].attachments.isNotEmpty) {
        final found =
            _messages[i].attachments.where((a) => a.hasBytes).toList();
        if (found.isNotEmpty) resendAtts = found;
        break;
      }
    }
    await sendWithText(
      'Respons kamu sebelumnya terpotong di tengah JSON aksi. '
      'Kirim ulang sebagai chunk PERTAMA yang lengkap dan valid (10-15 soal) + '
      'SATU blok ```json aksi dalam respons ini, lalu tulis satu baris "Masih ada X soal lagi — balas \'lanjut\' ya." '
      'Singkat saja penjelasannya agar tidak terpotong lagi.',
      pendingAttachments: resendAtts,
    );
  }

  /// Parse JSON aksi secara toleran (abaikan teks pengiring seperti
  /// "LANJUT: ..." di dalam/luar pagar). Lihat action_json_parse.dart.
  // Map<String, dynamic>? extractActionJson(String text) =>
  //     parseActionJson(text);

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
            // Validasi kunci jawaban DULU — JSON mentah AI tidak boleh
            // langsung ke server (pernah: 2 kunci / tanpa kunci tersimpan).
            final payload = _sanitizedAiQuestions(questions);
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
          // Validasi kunci jawaban DULU — JSON mentah AI tidak boleh
          // langsung ke server (pernah: 2 kunci / tanpa kunci tersimpan).
          final payload = _sanitizedAiQuestions(questions);
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
            // Validasi kunci edit AI (gagal jelas bila ambigu — jangan
            // simpan kunci ganda/hilang). Menulis balik opsi/kunci bersih.
            _sanitizeAiEdit(e, q.typeId, q);
            final optsRaw = e['options'] as List<dynamic>?;
            payload.add({
              'id': q.id,
              'typeId': e['typeId'] is num
                  ? (e['typeId'] as num).toInt()
                  : int.tryParse('${e['typeId']}') ?? q.typeId,
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
                          if (o.optionImage != null &&
                              o.optionImage!.isNotEmpty)
                            'optionImage': o.optionImage,
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
    _dismissKeyboard();
    final m = pendingActionMessage;
    if (m == null || _actionWorking) return;
    if (_streaming || _sending) {
      showAuthToast(context, 'Tunggu respons AI selesai dulu', isError: true);
      return;
    }
    setState(() => _actionWorking = true);
    try {
      final actionJson = m.actionJson;
      if (actionJson == null) {
        throw Exception('Data aksi rusak. Minta AI mengulang perubahannya.');
      }
      final result = await executeAction(actionJson);
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
    _dismissKeyboard();
    final m = pendingActionMessage;
    if (m == null || _actionWorking) return;
    if (_streaming || _sending) {
      showAuthToast(context, 'Tunggu respons AI selesai dulu', isError: true);
      return;
    }
    setState(() {
      _actionWorking = false;
      m.actionStatus = 'rejected';
      m.actionResult = null;
    });
    if (mounted) showAuthToast(context, 'Perubahan ditolak');
    await persistCurrent();
  }

  Future<void> sendWithText(String rawText, {List<AiAttachment>? pendingAttachments}) async {
    final hasFiles = pendingAttachments != null && pendingAttachments.isNotEmpty;
    if ((rawText.isEmpty && !hasFiles) || _streaming || _sending) return;
    if (!GeminiService.hasKey) {
      showAuthToast(context, 'API Key belum diatur', isError: true);
      showAiApiKeyDialog(
        context,
        onKeyChanged: () {
          if (mounted) setState(() {});
        },
      );
      return;
    }
    _sending = true;
    if (mounted) setState(() {});
    try {
      await _prepareAndStream(rawText, inlineAttachments: pendingAttachments);
    } catch (_) {
      _sending = false;
      if (mounted) setState(() {});
    }
  }

  /// Persiapan kirim (konteks + bubble) lalu mulai streaming.
  /// Dipanggil sekali per kirim; flag _sending dilepas saat streaming
  /// resmi mulai (atau saat method ini melempar).
  /// Konteks basi TIDAK dipakai diam-diam: bila build konteks form gagal
  /// dan tidak ada cache, kirim dibatalkan dengan penjelasan (hindari AI
  /// mengarang id soal dari konteks kedaluwarsa).
  Future<void> _prepareAndStream(String rawText, {List<AiAttachment>? inlineAttachments}) async {
    List<AiAttachment>? sendAttachments = inlineAttachments != null && inlineAttachments.isNotEmpty ? List<AiAttachment>.from(inlineAttachments) : null;
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
      } catch (_) {
        // Mention eksplisit tapi konteks gagal dimuat: batalkan, jangan
        // kirim tanpa konteks (AI akan mengarang id soal).
        if (!mounted) return;
        _sending = false;
        setState(() {});
        showAuthToast(
          context,
          'Form yang di-mention tidak bisa dimuat. Coba lagi.',
          isError: true,
        );
        return;
      }
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
        // Konteks segar gagal (form dihapus / offline): JANGAN pakai cache
        // basi diam-diam — batalkan kirim dengan penjelasan.
        if (!mounted) return;
        _sending = false;
        setState(() {});
        showAuthToast(
          context,
          'Konteks form kedaluwarsa. Mention ulang (@nama form) lalu kirim lagi.',
          isError: true,
        );
        return;
      }
    } else if (_lastFormContext != null && _lastFormContext!.isNotEmpty) {
      // Fallback terakhir: konteks cache tanpa form aktif yang diketahui.
      extraContext = _lastFormContext;
    }
    // URL reader: ambil isi link yang user sertakan di prompt (maks 3).
    // Halaman web → blok <URL_CONTEXT> di konteks; PDF/gambar → masuk
    // jalur lampiran (preview chip + inlineData) sehingga otomatis
    // tersimpan di history bersama pesan.
    final urlContexts = StringBuffer();
    final failedUrls = <String>[];
    for (final url in extractUrls(rawText).take(3)) {
      final result = await fetchUrlContext(url);
      if (result == null) {
        failedUrls.add(url);
        continue;
      }
      final att = result.attachment;
      if (att != null) {
        (sendAttachments ??= []).add(att);
        continue;
      }
      final text = result.textContext;
      if (text != null && text.isNotEmpty) {
        urlContexts.writeln();
        urlContexts.writeln('<URL_CONTEXT url="$url">');
        urlContexts.writeln(text);
        urlContexts.write('</URL_CONTEXT>');
      } else {
        failedUrls.add(url);
      }
    }
    if (urlContexts.isNotEmpty) {
      extraContext = '${extraContext ?? ''}$urlContexts'.trim();
    }
    if (failedUrls.isNotEmpty && mounted) {
      showAuthToast(
        context,
        failedUrls.length == 1
            ? 'Link tidak bisa dibuka (offline / butuh login / konten tidak terbaca).'
            : '${failedUrls.length} link tidak bisa dibuka.',
        isError: true,
      );
    }
    final displayText = rawText;
    final sendText =
        extraContext != null && extraContext.isNotEmpty
        ? '$extraContext\n\nPertanyaan user: $rawText'
        : rawText;
    // bersihkan mention picker + lampiran pending
    setState(() {
      _mentionCandidates = [];
      _isMentionActive = false;
      _pickedMentions.clear();
      _pendingAttachments.clear();
    });

    final userMsg = ChatMessage(role: 'user', text: displayText);
    if (sendAttachments != null) userMsg.attachments = sendAttachments;
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
      _sending = false; // persiapan selesai, giliran flag streaming
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
      _sub = GeminiService.streamChat(history, cancel: cancelToken, inlineAttachments: sendAttachments).listen(
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
            botMsg.text = 'AI tidak memberi jawaban. Coba lagi.';
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
          // Aksi form (buat/edit): TIDAK pakai dialog. Aksi disimpan sebagai
          // "pending" di pesan — ikut persist ke session, dan tombol
          // Terima/Tolak tampil di ATAS field prompt (PendingActionBar).
          // Terpotong (MAX_TOKENS) → notice + tombol Lanjutkan, bukan diam.
          await _finalizeAction(botMsg);
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
            botMsg.text = '$partial\n\nRespons terputus. Coba lagi untuk jawaban baru.';
            botMsg.isError = true;
            botMsg.disposeStream();
            if (!mounted) return;
            _typingStream?.dispose();
            _typingStream = null;
            _streamingMsg = null;
            _streamingBuffer = null;
            setState(() => _streaming = false);
            // Parsial bisa berupa JSON aksi terpotong → beri tombol Lanjutkan.
            await _finalizeAction(botMsg, allowUnknownFinish: true);
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
              inlineAttachments: sendAttachments,
            );
            if (botMsg != _streamingMsg) return; // di-stop saat fallback jalan
            if (full.trim().isEmpty) {
              botMsg.text = 'AI tidak memberi jawaban. Coba lagi.';
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
            // Samakan dengan jalur stream: parse aksi / tandai terpotong.
            await _finalizeAction(botMsg);
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
