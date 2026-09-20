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

  /// Metadata lampiran (tanpa bytes) — agar chip lampiran tetap tampil
  /// setelah restart. Bytes dimuat ulang dari disk lewat
  /// `AiAttachment.reloadBytes()`.
  final List<Map<String, dynamic>>? attachments;

  const FormAgentMessage({
    required this.isUser,
    required this.text,
    this.applied = const [],
    this.isError = false,
    this.attachments,
  });

  Map<String, dynamic> toJson() => {
        'isUser': isUser,
        'text': text,
        'applied': applied,
        'isError': isError,
        if (attachments != null) 'attachments': attachments,
      };

  /// Parse toleran: field bertipe salah diabaikan, bukan melempar.
  factory FormAgentMessage.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>>? atts;
    if (j['attachments'] is List) {
      atts = (j['attachments'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return FormAgentMessage(
      isUser: j['isUser'] == true,
      text: (j['text'] ?? '').toString(),
      applied: (j['applied'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      isError: j['isError'] == true,
      attachments: atts,
    );
  }
}

/// Satu percakapan AI Form Agent untuk sebuah form. Satu form bisa punya
/// beberapa sesi (tombol "Chat baru"), seperti riwayat AI Chat.
class FormAgentSession {
  final String id;
  String title;
  List<FormAgentMessage> messages;
  DateTime updatedAt;

  FormAgentSession({
    required this.id,
    required this.title,
    required this.messages,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Null bila sesi tak bisa dipakai (tanpa id) — dipakai loadSessions agar
  /// satu sesi rusak tidak menghapus seluruh riwayat form.
  static FormAgentSession? tryFromJson(Object? e) {
    if (e is! Map) return null;
    try {
      final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e);
      final id = m['id']?.toString() ?? '';
      if (id.isEmpty) return null;
      // Pesan rusak dilewati satu per satu — jangan gagalkan seluruh sesi.
      final messages = <FormAgentMessage>[];
      for (final raw in (m['messages'] as List<dynamic>? ?? [])) {
        if (raw is! Map) continue;
        try {
          messages.add(FormAgentMessage.fromJson(
            raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw),
          ));
        } catch (_) {}
      }
      return FormAgentSession(
        id: id,
        title: m['title']?.toString() ?? 'Chat',
        messages: messages,
        updatedAt: DateTime.tryParse(m['updatedAt']?.toString() ?? ''),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Riwayat chat AI Form Agent — TERPISAH dari [AiChatHistoryService]
/// (chat AI umum) dan dipisah per form: setiap form punya daftar sesinya
/// sendiri, sehingga konteks agent selalu fokus pada form itu.
class AiFormAgentHistoryService {
  static const _baseKey = 'ai_form_agent_v2';

  /// Format lama: satu daftar pesan datar per form (tanpa sesi).
  static const _legacyBaseKey = 'ai_form_agent_history_v1';

  /// Key per-akun + per-form; draf baru (belum punya id) memakai 'draft'.
  static String _keyFor(int? formId, {String? accountId}) {
    final account =
        (accountId ?? AuthService.email ?? '').trim().toLowerCase();
    final form = formId == null ? 'draft' : '$formId';
    return '$_baseKey:$account:$form';
  }

  static String _legacyKeyFor(int? formId, {String? accountId}) {
    final account =
        (accountId ?? AuthService.email ?? '').trim().toLowerCase();
    final form = formId == null ? 'draft' : '$formId';
    return '$_legacyBaseKey:$account:$form';
  }

  /// Bungkus format lama (daftar pesan) jadi satu sesi, lalu buang key lama.
  /// Dipanggil dari [loadSessions] sehingga berjalan sekali per form.
  static Future<void> _migrateLegacy(int? formId, {String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final legacyKey = _legacyKeyFor(formId, accountId: accountId);
    final raw = prefs.getString(legacyKey);
    if (raw == null || raw.isEmpty) return;
    await prefs.remove(legacyKey);
    // Key baru sudah ada isinya (mis. migrasi parsial) → jangan timpa.
    final newKey = _keyFor(formId, accountId: accountId);
    if (prefs.getString(newKey) != null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final messages = <FormAgentMessage>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          messages.add(FormAgentMessage.fromJson(
            item is Map<String, dynamic>
                ? item
                : Map<String, dynamic>.from(item),
          ));
        } catch (_) {}
      }
      if (messages.isEmpty) return;
      final session = FormAgentSession(
        id: 'legacy',
        title: _titleFrom(messages),
        messages: messages,
      );
      await prefs.setString(
        newKey,
        jsonEncode([session.toJson()]),
      );
    } catch (_) {}
  }

  /// Judul sesi = 40 karakter pertama pesan user (fallback pesan pertama).
  static String _titleFrom(List<FormAgentMessage> messages) {
    if (messages.isEmpty) return 'Chat baru';
    final text = messages
        .firstWhere((m) => m.isUser, orElse: () => messages.first)
        .text
        .trim();
    if (text.isEmpty) return 'Chat baru';
    return text.length > 40 ? '${text.substring(0, 40)}…' : text;
  }

  static String titleFor(List<FormAgentMessage> messages) =>
      _titleFrom(messages);

  /// Sesi terbaru di urutan paling depan.
  static Future<List<FormAgentSession>> loadSessions(
    int? formId, {
    String? accountId,
  }) async {
    await _migrateLegacy(formId, accountId: accountId);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(formId, accountId: accountId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final sessions = <FormAgentSession>[];
      for (final item in decoded) {
        final s = FormAgentSession.tryFromJson(item);
        if (s != null) sessions.add(s);
      }
      return sessions..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveSessions(
    int? formId,
    List<FormAgentSession> sessions, {
    String? accountId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode([for (final s in sessions) s.toJson()]);
    await prefs.setString(_keyFor(formId, accountId: accountId), raw);
  }

  static Future<void> upsert(
    int? formId,
    FormAgentSession session, {
    String? accountId,
  }) async {
    final all = await loadSessions(formId, accountId: accountId);
    final idx = all.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      all[idx] = session;
    } else {
      all.insert(0, session);
    }
    await saveSessions(formId, all, accountId: accountId);
  }

  static Future<void> delete(
    int? formId,
    String id, {
    String? accountId,
  }) async {
    final all = await loadSessions(formId, accountId: accountId);
    all.removeWhere((s) => s.id == id);
    await saveSessions(formId, all, accountId: accountId);
  }

  static Future<void> clearAll(int? formId, {String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(formId, accountId: accountId));
  }

  /// Dipakai saat draf baru disimpan (id didapat): pindahkan riwayat dari
  /// key 'draft' ke key form id agar percakapan tidak hilang.
  static Future<void> migrateDraftToForm(
    int formId, {
    String? accountId,
  }) async {
    final draftSessions = await loadSessions(null, accountId: accountId);
    if (draftSessions.isEmpty) return;
    final existing = await loadSessions(formId, accountId: accountId);
    final knownIds = {for (final s in existing) s.id};
    final merged = [
      ...existing,
      for (final s in draftSessions)
        if (!knownIds.contains(s.id)) s,
    ];
    await saveSessions(formId, merged, accountId: accountId);
    await clearAll(null, accountId: accountId);
  }
}
