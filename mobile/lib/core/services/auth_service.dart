import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ponytail: chain fallback .env, dart-define, default.
String get apiBaseUrl {
  final envUrl = dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null;
  if (envUrl != null && envUrl.isNotEmpty) return envUrl;
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );
}

/// Error API ramah user
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

/// URL lengkap gambar
String profileImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  final origin = apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  return path.startsWith('http') ? path : '$origin$path';
}

  /// Rate limit client
  // ponytail: penegakan di server, client anti-spam.
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
  // ponytail: tanpa retry, error cepat terlihat.
  static const Duration _timeout = Duration(seconds: 6);
  static const int _maxRetries = 0;

  static Duration get timeout => _timeout;

  // ponytail: token di shared_preferences tetap login.
  static String? token;

  static String? _email;

  static String? get email => _email;

  /// Callback saat sesi berakhir
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

  /// Ambil sesi tersimpan
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

  /// Pesan error untuk user
  static String errorMessage(Object e) =>
      e is ApiException ? e.message : 'Terjadi kesalahan yang tidak diketahui.';

  static bool isValidEmail(String email) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email);

  static const _serverDownMessage =
      'Server sedang offline. Silakan coba lagi nanti.';

  static Map<String, dynamic> _decode(http.Response response) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      if (response.statusCode >= 502 && response.statusCode <= 504) {
        throw const ApiException(_serverDownMessage);
      }
      throw const ApiException('Respons server tidak valid.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // ponytail: 5xx pesan generik tanpa detail.
      final serverMsg =
          (json['message'] as String?) ?? (json['Message'] as String?);
      throw ApiException(
        response.statusCode >= 500
            ? _serverDownMessage
            : (serverMsg ?? 'Terjadi kesalahan.'),
      );
    }
    return json;
  }

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
            'Server sedang offline. Silakan coba lagi nanti.',
          );
        }
      } on http.ClientException {
        if (attempt >= _maxRetries) {
          throw const ApiException(
            'Server sedang offline. Silakan coba lagi nanti.',
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
        await logout();
        onSessionExpired?.call();
        throw const ApiException(
          'Sesi Anda telah berakhir. Silakan login kembali.',
        );
      }
    }
    return _decode(response);
  }

  /// Deteksi 401 JWT
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

  /// POST /auth/refresh
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

  /// Refresh token
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

  /// POST /users/change-password
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

  /// Perbarui nama/username sesi
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

  /// Logout client
  static Future<void> logout() async {
    token = null;
    _email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kFullname);
    await prefs.remove(_kUsername);
    await prefs.remove(_kEmail);
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) => _send('POST', path, body, auth: true);

  static Future<Map<String, dynamic>> get(String path) =>
      _send('GET', path, null, auth: true);

  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) => _send('PUT', path, body, auth: true);

  static Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) => _send('PATCH', path, body, auth: true);

  static Future<Map<String, dynamic>> delete(String path) =>
      _send('DELETE', path, null, auth: true);
}
