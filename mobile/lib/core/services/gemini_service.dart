import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Token pembatalan request Gemini. [cancel] menutup koneksi HTTP
/// sehingga request yang menggantung langsung dibatalkan — tanpa ini,
/// subscription cancel saja tidak memutus request yang sedang menunggu
/// respons server.
class GeminiCancel {
  http.Client? _client;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void _attach(http.Client client) => _client = client;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    try {
      _client?.close();
    } catch (_) {}
  }
}

/// Layanan Google AI Studio (Gemini) untuk AI Chat.
/// - API key dapat diubah user di dalam app dan tersimpan persist (FlutterSecureStorage)
/// - Fallback ke .env `GEMINI_API_KEY` / `GOOGLE_AI_API_KEY` atau --dart-define jika belum diatur user
/// - Mendukung streaming realtime via `streamGenerateContent?alt=sse`
class GeminiService {
  static const _storageKey = 'gemini_api_key';
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static String? _userKey;
  static bool _initialized = false;

  /// Muat key & model yang tersimpan user (panggil di main sebelum runApp)
  static Future<void> init() async {
    if (_initialized) return;
    try {
      _userKey = await _secure.read(key: _storageKey);
      if (_userKey != null && _userKey!.trim().isEmpty) _userKey = null;
    } catch (_) {
      _userKey = null;
    }
    await _loadModel();
    _initialized = true;
  }

  static String get _envKey {
    final envKey = dotenv.isInitialized
        ? (dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['GOOGLE_AI_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'])
        : null;
    if (envKey != null && envKey.isNotEmpty) return envKey;
    const defineKey = String.fromEnvironment('GEMINI_API_KEY');
    if (defineKey.isNotEmpty) return defineKey;
    const defineKey2 = String.fromEnvironment('GOOGLE_AI_API_KEY');
    if (defineKey2.isNotEmpty) return defineKey2;
    return '';
  }

  /// Key efektif: prioritas user tersimpan > env > dart-define
  static String get _apiKey {
    if (_userKey != null && _userKey!.trim().isNotEmpty) return _userKey!.trim();
    return _envKey;
  }

  static bool get hasKey => _apiKey.isNotEmpty;

  /// Key yang disimpan user (null jika belum diatur)
  static String? get userKey => _userKey;

  /// True jika key berasal dari input user (bukan env)
  static bool get isUserKey => _userKey != null && _userKey!.trim().isNotEmpty;

  /// Simpan key dari input user (persist)
  static Future<void> setUserKey(String key) async {
    final v = key.trim();
    if (v.isEmpty) {
      await clearUserKey();
      return;
    }
    await _secure.write(key: _storageKey, value: v);
    _userKey = v;
  }

  /// Hapus key user (kembali ke env jika ada)
  static Future<void> clearUserKey() async {
    try {
      await _secure.delete(key: _storageKey);
    } catch (_) {}
    _userKey = null;
  }

  /// Mengubah error teknis (Inggris) menjadi pesan sederhana
  /// berbahasa Indonesia yang mudah dimengerti user awam:
  /// sebutkan penyebab + langkah yang bisa dilakukan user.
  static String friendlyMessage(Object e) {
    final t = e.toString().toLowerCase();
    bool hasAny(List<String> keys) => keys.any(t.contains);

    // Request dibatalkan user / oleh app (tombol stop, ganti sesi).
    if (hasAny(['gemini_cancelled', 'request cancelled', 'request aborted'])) {
      return 'Respons dihentikan. Ketuk "Coba lagi" jika ingin AI menjawab lagi.';
    }
    // Stream/respons selesai TANPA teks. Penyebab paling umum di model
    // thinking (Gemini 2.5/3.x): seluruh kuota token habis untuk proses
    // berpikir internal sehingga tidak ada jawaban yang terkirim.
    if (hasAny(['gemini_no_text'])) {
      return 'AI menyelesaikan permintaan tanpa menghasilkan jawaban — biasanya karena '
          'kuota token respons habis dipakai untuk proses berpikir internal model. '
          'Ketuk "Coba lagi" untuk mengulang; jika sering terjadi, mulai chat baru '
          'agar percakapan lebih ringkas.';
    }
    // Internet mati / DNS / koneksi ditolak — cek sebelum yang lain
    // karena pesan transport bisa mengandung kata umum seperti "failed".
    if (e is SocketException ||
        e is HttpException ||
        e is http.ClientException ||
        hasAny([
          'socketexception',
          'failed host lookup',
          'connection failed',
          'connection refused',
          'connection reset',
          'connection closed',
          'client closed',
          'network is unreachable',
          'no address associated',
          'no route to host',
        ])) {
      return 'Koneksi internet terputus, jadi AI tidak bisa dihubungi. '
          'Periksa WiFi/kuota internet kamu, lalu ketuk "Coba lagi" di bawah pesan ini.';
    }
    if (e is TimeoutException || hasAny(['timeoutexception', 'timed out'])) {
      return 'Server AI terlalu lama tidak merespons (koneksi lambat atau server sedang padat). '
          'Periksa kestabilan internet kamu, lalu ketuk "Coba lagi". '
          'Jika tetap gagal, coba beberapa saat lagi.';
    }
    // API key salah / kedaluwarsa (401/403 dari Google).
    if (hasAny([
      'api_key_invalid',
      'api key not valid',
      'invalid api key',
      'key not valid',
      'key expired',
      'permission_denied',
    ])) {
      return 'API Key tidak valid atau sudah kedaluwarsa, jadi Google menolak permintaan ini. '
          'Buka Pengaturan AI, perbarui API Key dari Google AI Studio, lalu kirim ulang pesannya.';
    }
    // Model tidak ada / sudah di-retire (404 dari Google).
    if (hasAny(['not_found', 'is not found', 'model not found', 'gemini error 404'])) {
      return 'Model AI yang dipilih tidak tersedia lagi di server Google. '
          'Buka Pengaturan AI, pilih model lain, lalu ketuk "Coba lagi".';
    }
    // Kuota / rate limit habis (429 dari Google).
    if (hasAny([
      'resource_exhausted',
      'quota',
      'rate limit',
      'too many requests',
      'gemini error 429',
    ])) {
      return 'Batas pemakaian AI untuk API Key ini sudah habis (biasanya terlalu banyak '
          'permintaan dalam waktu singkat). Tunggu sekitar 1 menit lalu ketuk "Coba lagi"; '
          'jika masih gagal, gunakan API Key lain di Pengaturan AI.';
    }
    // Token limit: histori + prompt melebihi kapasitas model (400).
    if (hasAny([
      'token',
      'too long',
      'too large',
      'max_tokens',
      'context length',
      'prompt too long',
    ])) {
      return 'Percakapan ini sudah terlalu panjang sehingga melebihi kapasitas AI. '
          'Mulai chat baru lewat menu drawer (tombol +), lalu ulangi pertanyaanmu di sana.';
    }
    // Respons diblokir filter keamanan Google.
    if (hasAny(['content_blocked', 'blockreason', 'safety', 'harm_category', 'prohibited_content'])) {
      return 'Pertanyaan ini diblokir oleh filter keamanan Google sehingga AI tidak boleh menjawab. '
          'Ini bukan bug aplikasi — coba rumuskan ulang pertanyaanmu dengan kata yang berbeda.';
    }
    // Server Google sibuk / error (500/503).
    if (hasAny([
      'unavailable',
      'overloaded',
      'internal error',
      'server error',
      'gemini error 500',
      'gemini error 502',
      'gemini error 503',
    ])) {
      return 'Server AI sedang bermasalah atau sedang sibuk (bukan karena aplikasi ini). '
          'Tunggu 1–2 menit, lalu ketuk "Coba lagi".';
    }
    return 'Maaf, terjadi kesalahan yang tidak diketahui saat AI menjawab. '
        'Ketuk "Coba lagi" untuk mengulang. Jika selalu gagal, coba mulai chat baru '
        'atau periksa API Key di Pengaturan AI.';
  }

  /// Untuk menampilkan preview aman (misal AIza...****)
  static String get maskedKey {
    final k = _apiKey;
    if (k.length <= 8) return '****';
    return '${k.substring(0, 6)}****${k.substring(k.length - 4)}';
  }

  static const _modelStorageKey = 'gemini_selected_model';
  static String _selectedModel = 'gemini-2.0-flash';
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  /// Daftar model yang diminta user (tampilkan apa adanya, map ke id API valid)
  static const List<String> availableModels = [
    'Gemini 2.5 Flash',
    'Gemini 2.5 Flash Lite',
    'Gemini 3.5 Flash',
    'Gemini 3.6 Flash',
    'Gemini 3.7 Flash',
    'Gemini 3.1 Flash Lite',
    'Gemini 3 Flash',
  ];

  static String _mapDisplayToId(String display) {
    // Alias stabil: selalu menunjuk model generasi terbaru yang tersedia di API
    // (menghindari 404 karena model lama di-retire, mis. gemini-2.0-flash)
    final v = display.toLowerCase();
    if (v.contains('lite')) return 'gemini-flash-lite-latest';
    return 'gemini-flash-latest';
  }

  static String get selectedModelDisplay {
    // reverse map id -> display kalau perlu, tapi simpan display langsung
    if (availableModels.contains(_selectedModel)) return _selectedModel;
    // id style -> display
    final id = _selectedModel;
    if (id == 'gemini-2.0-flash-lite') return 'Gemini 2.5 Flash Lite';
    return 'Gemini 2.5 Flash';
  }

  static String get selectedModelId => _mapDisplayToId(_selectedModel);

  static Future<void> setModel(String display) async {
    final v = display.trim();
    if (!availableModels.contains(v)) return;
    _selectedModel = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelStorageKey, v);
    } catch (_) {}
  }

  static Future<void> _loadModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_modelStorageKey);
      if (saved != null && availableModels.contains(saved)) {
        _selectedModel = saved;
      }
    } catch (_) {}
  }

  static const _systemPrompt = '''
Kamu adalah Asisten FormUp - AI Agent pembuat & pengedit formulir yang bisa membaca semua form milik user.
Tugas: membantu user membuat, membaca, dan mengedit form secara otomatis via percakapan.

Aturan:
- Jawab dengan Bahasa Indonesia yang ramah.
- Jika user mention form dengan @ (mis. @Judul Form), kamu akan menerima blok <FORM_CONTEXT> berisi detail form tersebut. Gunakan itu untuk menjawab akurat, jangan halusinasi ID/judul/soal.
- Jika user minta list form tanpa mention, jawab berdasarkan konteks yang diberikan (jika ada).
- Ketika user meminta membuat/mengedit form, selipkan BLOK JSON terstruktur agar aplikasi bisa mengeksekusi otomatis.
- Format JSON harus dalam code fence ```json dan valid:
  // Membuat form baru
  {"action":"create_form","title":"...","description":"...","questions":[{"typeId":1,"question":"...","isRequired":true,"options":[{"optionText":"...","isCorrect":true}],"points":10}]}
  // Menambah soal ke form existing
  {"action":"add_questions","formId":123,"questions":[...]}
  // Update pengaturan form
  {"action":"update_settings","formId":123,"settings":{"isExamMode":true,"themePrimaryColor":"#2A9D8F"}}
- typeId: 1=Essay, 2=Multiple Choice, 3=Checkbox, 4=DateTime, 5=TrueFalse
- Jika tidak ada aksi form, jangan paksa JSON - jawab percakapan biasa.
- Selalu jelaskan ringkas apa yang dibuat, lalu sertakan JSON di akhir jika ada aksi.
''';

  /// Kirim histori chat dan stream token balasan (realtime).
  /// [history] = list map {role: 'user'|'model', text: String}
  /// [cancel] = token pembatalan (dipakai tombol stop di input bar).
  static Stream<String> streamChat(
    List<Map<String, String>> history, {
    GeminiCancel? cancel,
  }) async* {
    if (!hasKey) {
      throw Exception('GEMINI_API_KEY belum diatur. Buka AI Chat > Atur API Key untuk menyimpannya di aplikasi.');
    }
    final effectiveModel = selectedModelId;
    final uri = Uri.parse('$_baseUrl/models/$effectiveModel:streamGenerateContent?alt=sse');
    // Build contents
    final contents = <Map<String, dynamic>>[];
    for (final m in history) {
      final role = m['role'] == 'model' ? 'model' : 'user';
      contents.add({
        'role': role,
        'parts': [
          {'text': m['text'] ?? ''}
        ]
      });
    }
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.8,
        'maxOutputTokens': 32768,
      }
    });

    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.headers['X-goog-api-key'] = _apiKey; // auth via header (format resmi), bukan query param
    request.body = body;

    // Request via http.Client (bukan Request.send langsung) agar bisa
    // di-abort dari luar lewat GeminiCancel.cancel() → client.close().
    final client = http.Client();
    cancel?._attach(client);
    try {
      if (cancel?.isCancelled ?? false) throw Exception('GEMINI_CANCELLED');
      // Fail-fast: tunggu respons server maksimal 15 detik. Kalau server
      // tidak merespons, lebih baik gagal cepat daripada user menunggu.
      final streamed = await client.send(request).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
            'Server AI tidak merespons dalam 15 detik (koneksi lambat atau server sibuk)'),
      );
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final errBody = await streamed.stream.bytesToString().timeout(
          const Duration(seconds: 10),
          onTimeout: () => '',
        );
        String msg = 'Gemini error ${streamed.statusCode}';
        try {
          final j = jsonDecode(errBody) as Map<String, dynamic>;
          msg = j['error']?['message'] as String? ?? msg;
        } catch (_) {
          if (errBody.isNotEmpty) msg = errBody;
        }
        throw Exception(msg);
      }

      // Parse SSE: lines starting with data:
      // Plus watchdog: kalau tidak ada chunk sama sekali selama 40 detik,
      // anggap koneksi mati — jangan biarkan "AI mengetik..." selamanya.
      // 40s (bukan lebih pendek) karena model thinking bisa diam cukup
      // lama sebelum token pertama, dan mid-stream chunk datang <1s.
      final sseLines = streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(
            const Duration(seconds: 40),
            onTimeout: (sink) {
              sink.addError(TimeoutException(
                  'Koneksi ke AI terputus di tengah respons (tidak ada data 40 detik)'));
              sink.close();
            },
          );
      // Diagnostik: kenapa stream bisa berakhir TANPA teks. Kasus paling
      // umum: model thinking (2.5/3.x) menghabiskan maxOutputTokens untuk
      // proses berpikir internal → finishReason MAX_TOKENS, parts kosong.
      var sawText = false;
      var sawCandidates = false;
      String? lastFinish;
      Object? lastParseError;
      await for (final chunk in sseLines) {
        final line = chunk.trim();
        if (line.isEmpty) continue;
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty) continue;
        try {
          final j = jsonDecode(data) as Map<String, dynamic>;
          // Respons diblokir filter keamanan: jangan telan diam-diam.
          final feedback = j['promptFeedback'] as Map<String, dynamic>?;
          if (feedback != null && feedback['blockReason'] != null) {
            throw Exception('GEMINI_CONTENT_BLOCKED_SAFETY');
          }
          final candidates = j['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) continue;
          sawCandidates = true;
          final first = candidates[0] as Map<String, dynamic>;
          final finish = (first['finishReason'] as String?)?.toUpperCase() ?? '';
          if (finish.isNotEmpty) lastFinish = finish;
          if (finish == 'SAFETY' || finish == 'PROHIBITED_CONTENT') {
            throw Exception('GEMINI_CONTENT_BLOCKED_SAFETY');
          }
          final content = first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts == null) continue;
          for (final p in parts) {
            final map = p as Map<String, dynamic>;
            // Lewati bagian "thought" (ringkasan proses berpikir internal)
            // agar tidak ikut tampil sebagai jawaban.
            if (map['thought'] == true) continue;
            final text = map['text'] as String?;
            // trim() kosong = bukan teks bermakna (mis. chunk "\n" saja) —
            // jangan dihitung sebagai konten agar diagnostik akurat.
            if (text != null && text.trim().isNotEmpty) {
              sawText = true;
              yield text;
            }
          }
        } catch (e) {
          // Penanda blokir keamanan harus diteruskan, bukan ditelan.
          if (e.toString().contains('GEMINI_CONTENT_BLOCKED')) rethrow;
          lastParseError = e;
          if (kDebugMode) debugPrint('[Gemini stream parse] $e : $data');
        }
      }
      // Stream selesai tanpa teks: jangan diam-diam (dulu jadi "Respons AI
      // kosong" tanpa penyebab) — lempar penanda berisi diagnostik.
      if (!sawText) {
        throw Exception(
            'GEMINI_NO_TEXT|finish=$lastFinish|candidates=$sawCandidates|parse=${lastParseError ?? '-'}');
      }
    } finally {
      client.close();
    }
  }

  /// Fallback non-stream: hasil lengkap sekaligus (dipakai jika stream gagal)
  static Future<String> generateOnce(
    List<Map<String, String>> history, {
    GeminiCancel? cancel,
  }) async {
    if (!hasKey) throw Exception('GEMINI_API_KEY belum diatur. Atur di AI Chat > API Key.');
    final effectiveModel = selectedModelId;
    final uri = Uri.parse('$_baseUrl/models/$effectiveModel:generateContent');
    final contents = <Map<String, dynamic>>[
      for (final m in history)
        {
          'role': m['role'] == 'model' ? 'model' : 'user',
          'parts': [
            {'text': m['text'] ?? ''}
          ]
        }
    ];
    final client = http.Client();
    cancel?._attach(client);
    try {
      if (cancel?.isCancelled ?? false) throw Exception('GEMINI_CANCELLED');
      final res = await client
          .post(uri,
              headers: {
                'Content-Type': 'application/json',
                'X-goog-api-key': _apiKey, // auth via header (format resmi), bukan query param
              },
              body: jsonEncode({
                'systemInstruction': {
                  'parts': [
                    {'text': _systemPrompt}
                  ]
                },
                'contents': contents,
                'generationConfig': {'temperature': 0.8, 'maxOutputTokens': 32768}
              }))
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
            'Server AI tidak merespons dalam 30 detik (koneksi lambat atau server sibuk)'),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        String msg = 'Gemini error ${res.statusCode}';
        try {
          final j = jsonDecode(res.body) as Map<String, dynamic>;
          msg = j['error']?['message'] as String? ?? msg;
        } catch (_) {}
        throw Exception(msg);
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final feedback = j['promptFeedback'] as Map<String, dynamic>?;
      if (feedback != null && feedback['blockReason'] != null) {
        throw Exception('GEMINI_CONTENT_BLOCKED_SAFETY');
      }
      final candidates = j['candidates'] as List<dynamic>?;
      final first =
          candidates != null && candidates.isNotEmpty ? candidates[0] as Map<String, dynamic> : null;
      final finish = (first?['finishReason'] as String?)?.toUpperCase() ?? '';
      if (finish == 'SAFETY' || finish == 'PROHIBITED_CONTENT') {
        throw Exception('GEMINI_CONTENT_BLOCKED_SAFETY');
      }
      final parts = (first?['content'] as Map<String, dynamic>?)?['parts'] as List<dynamic>?;
      final text = parts != null && parts.isNotEmpty
          ? (parts[0] as Map<String, dynamic>)['text'] as String?
          : null;
      // finishReason MAX_TOKENS tanpa teks = budget token habis untuk
      // proses berpikir internal model (thinking) — beri diagnostik, jangan
      // balikan string kosong yang membingungkan.
      if ((text == null || text.isEmpty) && finish == 'MAX_TOKENS') {
        throw Exception('GEMINI_NO_TEXT|finish=MAX_TOKENS');
      }
      return text ?? '';
    } finally {
      client.close();
    }
  }
}
