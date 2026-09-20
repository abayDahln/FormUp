import 'dart:convert';

import 'package:form_up/core/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Satu pesan riwayat AI Form Agent (tanpa aksi server — perubahan hanya
/// pada draf lokal, jadi cukup teks + ringkasan perubahan).
class FormAgentMessage {
  final bool isUser;
  final String text;

  /// Ringkasan perubahan draf yang diterapkan pada pesan ini.
  final List<String> applied;
  final bool isError;

  const FormAgentMessage({
    required this.isUser,
    required this.text,
    this.applied = const [],
    this.isError = false,
  });

  Map<String, dynamic> toJson() => {
        'isUser': isUser,
        'text': text,
        'applied': applied,
        'isError': isError,
      };

  /// Parse toleran: field bertipe salah diabaikan, bukan melempar.
  factory FormAgentMessage.fromJson(Map<String, dynamic> j) {
    return FormAgentMessage(
      isUser: j['isUser'] == true,
      text: (j['text'] ?? '').toString(),
      applied: (j['applied'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      isError: j['isError'] == true,
    );
  }
}

/// Riwayat chat AI Form Agent — TERPISAH dari [AiChatHistoryService]
/// (chat AI umum) dan dipisah per form: setiap form punya percakapan
/// sendiri, sehingga konteks agent selalu fokus pada form itu.
class AiFormAgentHistoryService {
  static const _baseKey = 'ai_form_agent_history_v1';

  /// Key per-akun + per-form; draf baru (belum punya id) memakai 'draft'.
  static String _keyFor(int? formId, {String? accountId}) {
    final account =
        (accountId ?? AuthService.email ?? '').trim().toLowerCase();
    final form = formId == null ? 'draft' : '$formId';
    return '$_baseKey:$account:$form';
  }

  static Future<List<FormAgentMessage>> load(
    int? formId, {
    String? accountId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(formId, accountId: accountId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) FormAgentMessage.fromJson(item),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(
    int? formId,
    List<FormAgentMessage> messages, {
    String? accountId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode([for (final m in messages) m.toJson()]);
    await prefs.setString(_keyFor(formId, accountId: accountId), raw);
  }

  static Future<void> clear(int? formId, {String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(formId, accountId: accountId));
  }

  /// Dipakai saat draf baru disimpan (id didapat): pindahkan riwayat dari
  /// key 'draft' ke key form id agar percakapan tidak hilang.
  static Future<void> migrateDraftToForm(
    int formId, {
    String? accountId,
  }) async {
    final draftMessages = await load(null, accountId: accountId);
    if (draftMessages.isEmpty) return;
    await save(formId, draftMessages, accountId: accountId);
    await clear(null, accountId: accountId);
  }
}