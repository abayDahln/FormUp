import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ponytail: fallback chain .env -> dart-define -> Android emulator default.
String get apiBaseUrl {
  final envUrl = dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null;
  if (envUrl != null && envUrl.isNotEmpty) return envUrl;
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );
}

/// Error API dengan pesan ramah untuk user (bukan detail teknis).
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

/// Rate limit sederhana di sisi client per endpoint.
/// ponytail: penegakan sebenarnya ada di server; ini hanya mencegah spam dari app.
class _RateLimiter {
  static const int _maxAttempts = 5;
  static const Duration _window = Duration(minutes: 1);
  static final Map<String, List<DateTime>> _hits = {};

  static void check(String key) {
    final now = DateTime.now();
    final recent =
        _hits[key]?.where((t) => now.difference(t) < _window).toList() ?? [];
    _hits[key] = recent;
    if (recent.length >= _maxAttempts) {
      throw const ApiException(
        'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.',
      );
    }
    recent.add(now);
  }
}

class AuthResult {
  final String token;
  final String fullname;
  final String username;
  final String email;

  AuthResult({
    required this.token,
    required this.fullname,
    required this.username,
    required this.email,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;
    return AuthResult(
      token: data['token'] as String,
      fullname: user['fullname'] as String? ?? '',
      username: user['username'] as String? ?? '',
      email: user['email'] as String? ?? '',
    );
  }
}

class AuthService {
  static const Duration _timeout = Duration(seconds: 10);
  static const int _maxRetries = 2;

  // ponytail: token disimpan di shared_preferences agar tetap login antar
  // restart app (JWT berlaku 7 hari).
  static String? token;

  static const _kToken = 'auth_token';
  static const _kFullname = 'auth_fullname';
  static const _kUsername = 'auth_username';
  static const _kEmail = 'auth_email';

  static Future<void> _persistSession(AuthResult result) async {
    token = result.token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, result.token);
    await prefs.setString(_kFullname, result.fullname);
    await prefs.setString(_kUsername, result.username);
    await prefs.setString(_kEmail, result.email);
  }

  /// Ambil sesi tersimpan dari disk (dipanggil saat app start).
  static Future<AuthResult?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_kToken);
    if (savedToken == null || savedToken.isEmpty) return null;
    token = savedToken;
    return AuthResult(
      token: savedToken,
      fullname: prefs.getString(_kFullname) ?? '',
      username: prefs.getString(_kUsername) ?? '',
      email: prefs.getString(_kEmail) ?? '',
    );
  }

  /// Pesan error aman ditampilkan ke user (tanpa detail teknis/token).
  static String errorMessage(Object e) =>
      e is ApiException ? e.message : 'Terjadi kesalahan yang tidak diketahui.';

  /// Validasi format email sederhana (keamanan input di sisi client).
  static bool isValidEmail(String email) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email);

  static Map<String, dynamic> _decode(http.Response response) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('Respons server tidak valid.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(json['message'] as String? ?? 'Terjadi kesalahan.');
    }
    return json;
  }

  /// POST dengan timeout + retry saat koneksi tidak stabil.
  static Future<http.Response> _request(
    String path,
    Map<String, dynamic>? body,
    Map<String, String> headers,
  ) async {
    var attempt = 0;
    while (true) {
      try {
        return await http
            .post(
              Uri.parse('$apiBaseUrl$path'),
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(_timeout);
      } on TimeoutException {
        if (attempt >= _maxRetries) {
          throw const ApiException(
            'Koneksi tidak stabil. Periksa koneksi internet Anda.',
          );
        }
      } on http.ClientException {
        if (attempt >= _maxRetries) {
          throw const ApiException(
            'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
          );
        }
      }
      attempt++;
      await Future.delayed(Duration(milliseconds: 500 * attempt));
    }
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final headers = {'Content-Type': 'application/json; charset=UTF-8'};
    if (auth && token != null) headers['Authorization'] = 'Bearer $token';

    var response = await _request(path, body, headers);

    if (auth &&
        response.statusCode == 401 &&
        response.headers['token-expired'] == 'true') {
      if (await _refresh()) {
        headers['Authorization'] = 'Bearer $token';
        response = await _request(path, body, headers);
      }
    }
    return _decode(response);
  }

  /// POST /auth/refresh — ambil token baru memakai token lama, tanpa body.
  static Future<bool> _refresh() async {
    if (token == null) return false;
    try {
      final response = await _request('/auth/refresh', null, {
        'Authorization': 'Bearer $token',
      });
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      token = (json['data'] as Map<String, dynamic>)['token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, token!);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<AuthResult> login(String email, String password) async {
    _RateLimiter.check('/auth/login');
    final json = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    final result = AuthResult.fromJson(json);
    await _persistSession(result);
    return result;
  }

  static Future<String> register({
    required String fullname,
    String? username,
    required String email,
    required String password,
  }) async {
    _RateLimiter.check('/auth/register');
    final json = await _post('/auth/register', {
      'fullname': fullname,
      'username': username,
      'email': email,
      'password': password,
    });
    return json['message'] as String? ?? 'OTP telah dikirim';
  }

  static Future<AuthResult> verifyRegistration({
    required String fullname,
    String? username,
    required String email,
    required String password,
    required String otp,
  }) async {
    _RateLimiter.check('/auth/verify-registration');
    final json = await _post('/auth/verify-registration', {
      'fullname': fullname,
      'username': username,
      'email': email,
      'password': password,
      'otp': otp,
    });
    final result = AuthResult.fromJson(json);
    await _persistSession(result);
    return result;
  }

  static Future<String> forgotPassword(String email) async {
    _RateLimiter.check('/auth/forgot-password');
    final json = await _post('/auth/forgot-password', {'email': email});
    return json['message'] as String? ?? 'OTP telah dikirim';
  }

  static Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    _RateLimiter.check('/auth/reset-password');
    final json = await _post('/auth/reset-password', {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
    return json['message'] as String? ?? 'Password berhasil direset';
  }

  /// Logout di sisi client — bersihkan token (backend tidak punya endpoint logout).
  static Future<void> logout() async {
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kFullname);
    await prefs.remove(_kUsername);
    await prefs.remove(_kEmail);
  }

  /// POST generik untuk endpoint lain (forms, questions, dll) — memakai token,
  /// retry, dan auto-refresh yang sama seperti endpoint auth.
  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) => _post(path, body, auth: true);
}
