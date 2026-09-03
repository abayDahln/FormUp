import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  /// Muat key yang tersimpan user (panggil di main sebelum runApp)
  static Future<void> init() async {
    if (_initialized) return;
    try {
      _userKey = await _secure.read(key: _storageKey);
      if (_userKey != null && _userKey!.trim().isEmpty) _userKey = null;
    } catch (_) {
      _userKey = null;
    }
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

  /// Untuk menampilkan preview aman (misal AIza...****)
  static String get maskedKey {
    final k = _apiKey;
    if (k.length <= 8) return '****';
    return '${k.substring(0, 6)}****${k.substring(k.length - 4)}';
  }

  static const _model = 'gemini-2.0-flash';
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  static const _systemPrompt = '''
Kamu adalah Asisten FormUp - AI pembuat & pengedit formulir.
Tugas: membantu user membuat dan mengedit form secara otomatis via percakapan.

Aturan:
- Jawab dengan Bahasa Indonesia yang ramah.
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
    final uri = Uri.parse('$_baseUrl/models/$_model:streamGenerateContent?alt=sse&key=$_apiKey');
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
    request.body = body;

    final streamed = await request.send();
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
        final candidates = j['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) continue;
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts == null) continue;
        for (final p in parts) {
          final text = (p as Map<String, dynamic>)['text'] as String?;
          if (text != null && text.isNotEmpty) {
            yield text;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Gemini stream parse] $e : $data');
      }
    }
  }

  /// Fallback non-stream: hasil lengkap sekaligus (dipakai jika stream gagal)
  static Future<String> generateOnce(List<Map<String, String>> history) async {
    if (!hasKey) throw Exception('GEMINI_API_KEY belum diatur. Atur di AI Chat > API Key.');
    final uri = Uri.parse('$_baseUrl/models/$_model:generateContent?key=$_apiKey');
    final contents = <Map<String, dynamic>>[
      for (final m in history)
        {
          'role': m['role'] == 'model' ? 'model' : 'user',
          'parts': [
            {'text': m['text'] ?? ''}
          ]
        }
    ];
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': _systemPrompt}
            ]
          },
          'contents': contents,
          'generationConfig': {'temperature': 0.8, 'maxOutputTokens': 8192}
        }));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Gemini error ${res.statusCode}';
      try {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        msg = j['error']?['message'] as String? ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = j['candidates'] as List<dynamic>?;
    final text = candidates?[0]['content']?['parts']?[0]['text'] as String?;
    return text ?? '';
  }
}
