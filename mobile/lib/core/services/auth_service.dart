import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:form_up/core/cache/api_cache.dart';
import 'package:form_up/core/services/network_status.dart';

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
  final DateTime expiresAt;
  final String fullname;
  final String username;
  final String email;
  final String role;

  AuthResult({
    required this.token,
    required this.expiresAt,
    required this.fullname,
    required this.username,
    required this.email,
    this.role = 'USER',
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;
    return AuthResult(
      token: data['token'] as String,
      expiresAt: AuthService._parseExpiresAt(data),
      fullname: user['fullname'] as String? ?? '',
      username: user['username'] as String? ?? '',
      email: user['email'] as String? ?? '',
      role: user['role'] as String? ?? 'USER',
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
  static DateTime? _expiresAt;

  static String? _email;
  static String? _role;
  static bool _rememberMe = true;
  static Timer? _sessionTimer;
  static bool _sessionRefreshInProgress = false;

  static String? get email => _email;
  static DateTime? get expiresAt => _expiresAt;

  /// Role user login ('ADMIN' / 'USER')
  static String get role => _role ?? 'USER';

  /// Scope cache per sesi user untuk mencegah data lintas akun ikut terbaca.
  static String get cacheScope => '${email ?? 'anon'}|$role';

  /// Ingat saya: true = sesi tersimpan (auto-login sampai token kedaluwarsa),
  /// false = sesi hanya hidup selama aplikasi terbuka.
  static bool get rememberMe => _rememberMe;

  /// Callback saat sesi berakhir
  static void Function()? onSessionExpired;

  static const _kToken = 'auth_token';
  static const _kFullname = 'auth_fullname';
  static const _kUsername = 'auth_username';
  static const _kEmail = 'auth_email';
  static const _kRole = 'auth_role';
  static const _kRemember = 'auth_remember';
  static const _kExpiresAt = 'auth_expires_at';
  static const _offlineMessage =
      'Kamu sedang offline. Login dan perubahan data tidak tersedia.';

  static DateTime _nowUtc() => DateTime.now().toUtc();

  static DateTime _parseExpiresAt(Map<String, dynamic> json) {
    final raw = json['expiresAt'] ?? json['expires_at'];
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toUtc() ?? _nowUtc();
    }
    if (raw is DateTime) return raw.toUtc();
    return _nowUtc();
  }

  static void _cancelSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  static void _scheduleSessionRefresh() {
    _cancelSessionTimer();
    if (!_rememberMe || token == null || _expiresAt == null) return;

    final delay = _expiresAt!.difference(_nowUtc());
    if (delay <= Duration.zero) {
      unawaited(_refreshPersistedSession());
      return;
    }

    _sessionTimer = Timer(delay, () {
      unawaited(_refreshPersistedSession());
    });
  }

  static Future<void> _refreshPersistedSession() async {
    if (_sessionRefreshInProgress || token == null) return;
    _sessionRefreshInProgress = true;
    try {
      final refreshed = await _refresh();
      if (refreshed) return;
      await logout();
      onSessionExpired?.call();
    } finally {
      _sessionRefreshInProgress = false;
    }
  }



  static Future<void> _persistSession(AuthResult result) async {
    token = result.token;
    _expiresAt = result.expiresAt;
    _email = result.email;
    _role = result.role;
    _rememberMe = true;
    final prefs = await SharedPreferences.getInstance();

    try {
      await prefs.setString(_kToken, result.token);
      await prefs.setString(_kFullname, result.fullname);
      await prefs.setString(_kUsername, result.username);
      await prefs.setString(_kEmail, result.email);
      await prefs.setString(_kRole, result.role);
      await prefs.setString(_kExpiresAt, result.expiresAt.toUtc().toIso8601String());
      await prefs.setBool(_kRemember, true);
      if (kDebugMode) {
        debugPrint('[Auth] Session persisted: email=${result.email}, expiresAt=${result.expiresAt}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] ERROR persisting session: $e');
      rethrow;
    }
    _scheduleSessionRefresh();
  }

  /// Ambil sesi tersimpan
  static Future<AuthResult?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _rememberMe = prefs.getBool(_kRemember) ?? true;
    final savedToken = prefs.getString(_kToken);
    final savedExpiresAtStr = prefs.getString(_kExpiresAt);
    final savedEmail = prefs.getString(_kEmail);
    final savedRole = prefs.getString(_kRole);

    if (kDebugMode) {
      debugPrint('[Auth] restoreSession: rememberMe=$_rememberMe, '
          'token=${savedToken == null ? "tidak ada" : "ada"} '
          'expiresAtStr=${savedExpiresAtStr ?? "null"} '
          'email=${savedEmail ?? "null"}');
    }

    if (savedToken == null || savedToken.isEmpty) {
      if (kDebugMode) debugPrint('[Auth] No saved token found');
      return null;
    }

    token = savedToken;
    _email = savedEmail ?? '';
    _role = savedRole ?? 'USER';

    DateTime? parsedExpiresAt;
    if (savedExpiresAtStr != null && savedExpiresAtStr.isNotEmpty) {
      parsedExpiresAt = DateTime.tryParse(savedExpiresAtStr)?.toUtc();
      if (kDebugMode) debugPrint('[Auth] Parsed expiresAt: $parsedExpiresAt');
    }

    // Jika expiresAt tidak valid/parse gagal, anggap expired tapi jangan logout
    if (parsedExpiresAt == null || _nowUtc().isAfter(parsedExpiresAt)) {
      if (kDebugMode) debugPrint('[Auth] Token expired or invalid expiresAt, keeping session for auto-refresh');
      _expiresAt = parsedExpiresAt;
      await NetworkStatus.refresh();
      if (NetworkStatus.isOnline) {
        unawaited(_refresh()); // fire-and-forget
      }
      _scheduleSessionRefresh();
    } else {
      _expiresAt = parsedExpiresAt;
      _scheduleSessionRefresh();
    }

    if (kDebugMode) {
      debugPrint('[Auth] Session restored for ${_email ?? "?"}');
    }
    return AuthResult(
      token: token ?? savedToken,
      expiresAt: _expiresAt ?? _nowUtc().add(const Duration(days: 14)), // fallback panjang
      fullname: prefs.getString(_kFullname) ?? '',
      username: prefs.getString(_kUsername) ?? '',
      email: _email!,
      role: _role!,
    );
  }

  /// Pesan error untuk user
  static String errorMessage(Object e) => switch (e) {
        ApiException(:final message) => message,
        OfflineCacheException(:final message) => message,
        _ => 'Terjadi kesalahan yang tidak diketahui.',
      };

  static bool isValidEmail(String email) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email);

  static const _serverDownMessage =
      'Terjadi gangguan pada layanan. Silakan coba lagi nanti.';
  static const _connectionMessage =
      'Gagal terhubung. Periksa koneksi internet kamu dan coba lagi.';
  static const _invalidResponseMessage =
      'Terjadi kesalahan, coba lagi nanti.';

  static Map<String, dynamic> _decode(http.Response response) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      if (response.statusCode >= 502 && response.statusCode <= 504) {
        throw const ApiException(_serverDownMessage);
      }
      throw const ApiException(_invalidResponseMessage);
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
    if (NetworkStatus.isOffline) {
      await NetworkStatus.refresh();
      if (NetworkStatus.isOffline) {
        throw const ApiException(_offlineMessage);
      }
    }
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
        final response = await http.Response.fromStream(streamed);
        NetworkStatus.markOnline();
        return response;
      } on TimeoutException {
        NetworkStatus.markOffline();
        if (attempt >= _maxRetries) {
          throw const ApiException(_connectionMessage);
        }
      } on http.ClientException {
        NetworkStatus.markOffline();
        if (attempt >= _maxRetries) {
          throw const ApiException(_connectionMessage);
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
      final data = json['data'] as Map<String, dynamic>;
      token = data['token'] as String;
      _expiresAt = _parseExpiresAt(data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, token!);
      if (_expiresAt != null) {
        await prefs.setString(
          _kExpiresAt,
          _expiresAt!.toUtc().toIso8601String(),
        );
      }
      _scheduleSessionRefresh();
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
    if (!_rememberMe) return;
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
    _cancelSessionTimer();
    token = null;
    _expiresAt = null;
    _email = null;
    _role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kFullname);
    await prefs.remove(_kUsername);
    await prefs.remove(_kEmail);
    await prefs.remove(_kRole);
    await prefs.remove(_kRemember);
    await prefs.remove(_kExpiresAt);
    await ApiCache.clear();
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) {
    return _send('POST', path, body, auth: true);
  }

  static Future<Map<String, dynamic>> get(String path) {
    return ApiCache.get(
      'http:get:${cacheScope}:$path',
      const Duration(minutes: 30),
      () => _send('GET', path, null, auth: true),
    );
  }

  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) {
    return _send('PUT', path, body, auth: true);
  }

  static Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) {
    return _send('PATCH', path, body, auth: true);
  }

  static Future<Map<String, dynamic>> delete(String path) =>
      _send('DELETE', path, null, auth: true);
}
