import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Data profil user hasil `GET/PUT /users/me` (UserDto dari backend).
class UserProfile {
  final int id;
  final String fullname;
  final String username;
  final String email;
  final String? role;
  final String? profileImage;
  final String? birthdate; // format yyyy-MM-dd atau null
  final bool? isActive;

  const UserProfile({
    required this.id,
    required this.fullname,
    required this.username,
    required this.email,
    this.role,
    this.profileImage,
    this.birthdate,
    this.isActive,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as int,
        fullname: json['fullname'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String?,
        profileImage: json['profileImage'] as String?,
        birthdate: json['birthdate'] as String?,
        isActive: json['isActive'] as bool?,
      );
}

/// Statistik profil hasil `GET /users/me/stats`.
class UserStats {
  final int totalForms;
  final int totalResponses;
  final int totalFeedbackGiven;

  const UserStats({
    this.totalForms = 0,
    this.totalResponses = 0,
    this.totalFeedbackGiven = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        totalForms: json['totalForms'] as int? ?? 0,
        totalResponses: json['totalResponses'] as int? ?? 0,
        totalFeedbackGiven: json['totalFeedbackGiven'] as int? ?? 0,
      );
}

/// Klien endpoint profil & foto profil (`/users/me`, `/users/me/profile-image`).
class UserService {
  /// GET /users/me — ambil profil user yang sedang login.
  static Future<UserProfile> getProfile() async {
    final json = await AuthService.get('/users/me');
    return UserProfile.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// GET /users/me/stats — ringkasan form/respons/feedback milik user.
  static Future<UserStats> getStats() async {
    final json = await AuthService.get('/users/me/stats');
    return UserStats.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// PUT /users/me — update fullname/username/birthdate.
  static Future<UserProfile> updateProfile({
    required String fullname,
    required String username,
    String? birthdate,
  }) async {
    final json = await AuthService.put('/users/me', {
      'fullname': fullname,
      'username': username,
      if (birthdate != null && birthdate.isNotEmpty) 'birthdate': birthdate,
    });
    return UserProfile.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// POST /users/me/profile-image — upload foto profil (multipart, field `file`).
  /// Mengembalikan path relatif gambar (mis. `/profile/xxx.png`).
  static Future<String> uploadProfileImage(
    Uint8List bytes,
    String filename,
  ) async {
    final uri = Uri.parse('$apiBaseUrl/users/me/profile-image');
    var response = await _upload(uri, bytes, filename);
    if (response.statusCode == 401 &&
        response.headers['token-expired'] == 'true' &&
        await AuthService.refreshToken()) {
      response = await _upload(uri, bytes, filename);
    }
    return _profileImageOf(response);
  }

  static Future<http.Response> _upload(
    Uri uri,
    Uint8List bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer ${AuthService.token}';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final streamed = await request.send().timeout(AuthService.timeout);
    return await http.Response.fromStream(streamed);
  }

  static String _profileImageOf(http.Response response) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('Respons server tidak valid.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(json['message'] as String? ?? 'Terjadi kesalahan.');
    }
    final data = json['data'] as Map<String, dynamic>?;
    return data?['profileImage'] as String? ?? '';
  }
}
