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

/// Ubah path relatif gambar (mis. `/profile/xxx.png`) jadi URL lengkap
/// berdasarkan host API yang sama.
String profileImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  final origin = apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  return path.startsWith('http') ? path : '$origin$path';
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
  // ponytail: 6s x 2 percobaan = max ~12s sebelum error, cukup untuk LAN
  // (sebelumnya 10s x 3 = 30s, terasa seperti hang saat host tidak terjangkau).
  static const Duration _timeout = Duration(seconds: 6);
  static const int _maxRetries = 1;

  /// Timeout HTTP dipakai juga oleh service lain (mis. upload multipart).
  static Duration get timeout => _timeout;

  // ponytail: token disimpan di shared_preferences agar tetap login antar
  // restart app (JWT berlaku 7 hari).
  static String? token;

  static String? _email;

  /// Email user yang sedang login (dari sesi tersimpan / hasil login).
  static String? get email => _email;

  /// Dipanggil saat sesi berakhir (token kadaluarsa & refresh gagal) agar
  /// app kembali ke halaman login. Didaftarkan di main().
  static void Function()? onSessionExpired;

  static const _kToken = 'auth_token';
  static const _kFullname = 'auth_fullname';
  static const _kUsername = 'auth_username';
  static const _kEmail = 'auth_email';

  static Future<void> _persistSession(AuthResult result) async {
    token = result.token;
    _email = result.email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, result.token);
    await prefs.setString(_kFullname, result.fullname);
    await prefs.setString(_kUsername, result.username);
    await prefs.setString(_kEmail, result.email);
  }

  /// Ambil sesi tersimpan dari disk (dipanggil saat app start).
  static Future<AuthResult?> restoreSession() async {    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_kToken);
    if (savedToken == null || savedToken.isEmpty) return null;
    token = savedToken;
    _email = prefs.getString(_kEmail) ?? '';
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

  static const _serverDownMessage =
      'Server sedang tidak aktif. Silakan coba lagi beberapa saat kemudian.';

  static Map<String, dynamic> _decode(http.Response response) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // 502/503/504 = server/proxy mati → body bukan JSON (HTML), beri pesan jelas.
      if (response.statusCode >= 502 && response.statusCode <= 504) {
        throw const ApiException(_serverDownMessage);
      }
      throw const ApiException('Respons server tidak valid.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // ponytail: terima `message` & `Message` — body 401 JWT diserialisasi PascalCase.
      throw ApiException(
        (json['message'] as String?) ??
            (json['Message'] as String?) ??
            (response.statusCode >= 502 && response.statusCode <= 504
                ? _serverDownMessage
                : 'Terjadi kesalahan.'),
      );
    }
    return json;
  }

  /// HTTP dengan timeout + retry saat koneksi tidak stabil.
  static Future<http.Response> _request(
    String method,
    String path,
    Map<String, dynamic>? body,
    Map<String, String> headers,
  ) async {
    var attempt = 0;
    while (true) {
      try {
        final request = http.Request(method, Uri.parse('$apiBaseUrl$path'));
        request.headers.addAll(headers);
        if (body != null) {
          request.headers['Content-Type'] = 'application/json; charset=UTF-8';
          request.body = jsonEncode(body);
        }
        final streamed = await request.send().timeout(_timeout);
        return await http.Response.fromStream(streamed);
      } on TimeoutException {
        if (attempt >= _maxRetries) {
          throw const ApiException(
            'Koneksi tidak stabil. Periksa koneksi internet Anda.',
          );
        }
      } on http.ClientException {
        if (attempt >= _maxRetries) {
          throw const ApiException(
            'Tidak dapat terhubung ke server. Pastikan server API sudah dijalankan, lalu periksa koneksi internet Anda.',
          );
        }
      }
      attempt++;
      await Future.delayed(Duration(milliseconds: 500 * attempt));
    }
  }

  static Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, dynamic>? body, {
    bool auth = false,
  }) async {
    final headers = <String, String>{};
    if (auth && token != null) headers['Authorization'] = 'Bearer $token';

    var response = await _request(method, path, body, headers);

    if (auth && response.statusCode == 401 && _isAuthRejected(response)) {
      if (await _refresh()) {
        headers['Authorization'] = 'Bearer $token';
        response = await _request(method, path, body, headers);
      } else {
        // Token tidak valid/kedaluwarsa dan refresh gagal → sesi berakhir.
        await logout();
        onSessionExpired?.call();
        throw const ApiException(
          'Sesi Anda telah berakhir. Silakan login kembali.',
        );
      }
    }
    return _decode(response);
  }

  /// Deteksi 401 dari lapisan JWT (bukan 401 konten, mis. token form salah).
  static bool _isAuthRejected(http.Response response) {
    if (response.headers['token-expired']?.toLowerCase() == 'true') return true;
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final message = (json['message'] ?? json['Message'] ?? '') as String;
      return message.toLowerCase() == 'unauthorized';
    } catch (_) {
      return false;
    }
  }

  /// POST /auth/refresh — ambil token baru memakai token lama, tanpa body.
  static Future<bool> _refresh() async {
    if (token == null) return false;
    try {
      final response = await _request('POST', '/auth/refresh', null, {
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

  /// Refresh token (publik) — dipakai service lain saat upload 401.
  static Future<bool> refreshToken() => _refresh();

  static Future<AuthResult> login(String email, String password) async {
    _RateLimiter.check('/auth/login');
    final json = await _send('POST', '/auth/login', {
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
    final json = await _send('POST', '/auth/register', {
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
    final json = await _send('POST', '/auth/verify-registration', {
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
    final json = await _send('POST', '/auth/forgot-password', {'email': email});
    return json['message'] as String? ?? 'OTP telah dikirim';
  }

  static Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    _RateLimiter.check('/auth/reset-password');
    final json = await _send('POST', '/auth/reset-password', {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
    return json['message'] as String? ?? 'Password berhasil direset';
  }

  /// POST /users/change-password — ganti password akun yang sedang login.
  static Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _RateLimiter.check('/users/change-password');
    final json = await _send(
      'POST',
      '/users/change-password',
      {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
      auth: true,
    );
    return json['message'] as String? ?? 'Password berhasil diubah';
  }

  /// Perbarui nama/username tersimpan di sesi (dipanggil setelah edit profil).
  static Future<void> updateSession({
    String? fullname,
    String? username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (fullname != null && fullname.isNotEmpty) {
      await prefs.setString(_kFullname, fullname);
    }
    if (username != null && username.isNotEmpty) {
      await prefs.setString(_kUsername, username);
    }
  }

  /// Logout di sisi client — bersihkan token (backend tidak punya endpoint logout).
  static Future<void> logout() async {
    token = null;
    _email = null;
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
  ) => _send('POST', path, body, auth: true);

  /// GET generik ber-auth (forms, questions, profile, dsb).
  static Future<Map<String, dynamic>> get(String path) =>
      _send('GET', path, null, auth: true);

  /// PUT generik ber-auth (update form, questions, dsb).
  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) => _send('PUT', path, body, auth: true);

  /// PATCH generik ber-auth (update settings, dsb).
  static Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) => _send('PATCH', path, body, auth: true);

  /// DELETE generik ber-auth.
  static Future<Map<String, dynamic>> delete(String path) =>
      _send('DELETE', path, null, auth: true);
}
