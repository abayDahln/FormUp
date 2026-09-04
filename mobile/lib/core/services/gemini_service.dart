import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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
  /// berbahasa Indonesia yang mudah dimengerti user awam.
  static String friendlyMessage(Object e) {
    final t = e.toString().toLowerCase();
    bool hasAny(List<String> keys) => keys.any(t.contains);

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
          'network is unreachable',
          'no address associated',
          'no route to host',
        ])) {
      return 'Internet kamu terputus. Periksa koneksi internet lalu coba lagi.';
    }
    if (e is TimeoutException || hasAny(['timeoutexception', 'timed out'])) {
      return 'Koneksi ke AI lambat. Coba lagi dengan internet yang lebih stabil.';
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
      return 'API Key tidak valid. Periksa key di Pengaturan AI lalu coba lagi.';
    }
    // Model tidak ada / sudah di-retire (404 dari Google).
    if (hasAny(['not_found', 'is not found', 'model not found', 'gemini error 404'])) {
      return 'Model AI tidak tersedia. Ganti model di Pengaturan AI lalu coba lagi.';
    }
    // Kuota / rate limit habis (429 dari Google).
    if (hasAny([
      'resource_exhausted',
      'quota',
      'rate limit',
      'too many requests',
      'gemini error 429',
    ])) {
      return 'Batas pemakaian AI habis. Tunggu sebentar lalu coba lagi.';
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
      return 'Chat terlalu panjang. Mulai chat baru lalu coba lagi.';
    }
    // Respons diblokir filter keamanan Google.
    if (hasAny(['content_blocked', 'blockreason', 'safety', 'harm_category', 'prohibited_content'])) {
      return 'Pertanyaan ini tidak bisa dijawab AI. Coba ubah kata-katanya.';
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
      return 'Server AI sedang sibuk. Tunggu sebentar lalu coba lagi.';
    }
    return 'Maaf, AI gagal menjawab. Coba lagi.';
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
  static Stream<String> streamChat(List<Map<String, String>> history) async* {
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
        'maxOutputTokens': 8192,
      }
    });

    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.headers['X-goog-api-key'] = _apiKey; // auth via header (format resmi), bukan query param
    request.body = body;

    final streamed = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw TimeoutException('Stream Gemini timeout'),
    );
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final errBody = await streamed.stream.bytesToString();
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
    await for (final chunk in streamed.stream.transform(utf8.decoder).transform(const LineSplitter())) {
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
        final first = candidates[0] as Map<String, dynamic>;
        final finish = (first['finishReason'] as String?)?.toUpperCase() ?? '';
        if (finish == 'SAFETY' || finish == 'PROHIBITED_CONTENT') {
          throw Exception('GEMINI_CONTENT_BLOCKED_SAFETY');
        }
        final content = first['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts == null) continue;
        for (final p in parts) {
          final text = (p as Map<String, dynamic>)['text'] as String?;
          if (text != null && text.isNotEmpty) {
            yield text;
          }
        }
      } catch (e) {
        // Penanda blokir keamanan harus diteruskan, bukan ditelan.
        if (e.toString().contains('GEMINI_CONTENT_BLOCKED')) rethrow;
        if (kDebugMode) debugPrint('[Gemini stream parse] $e : $data');
      }
    }
  }

  /// Fallback non-stream: hasil lengkap sekaligus (dipakai jika stream gagal)
  static Future<String> generateOnce(List<Map<String, String>> history) async {
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
    final res = await http
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
              'generationConfig': {'temperature': 0.8, 'maxOutputTokens': 8192}
            }))
        .timeout(
      const Duration(seconds: 90),
      onTimeout: () => throw TimeoutException('Generate Gemini timeout'),
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
    return text ?? '';
  }
}
