import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatHistoryMessage {
  final String role;
  String text;

  /// Aksi form yang diajukan AI di pesan ini (create_form, dll) + statusnya,
  /// agar aksi "pending" tetap ada saat berpindah session.
  Map<String, dynamic>? actionJson;
  String? actionStatus;
  String? actionResult;

  /// Form terlibat aksi (tersimpan agar tombol "Buka Form" tetap ada
  /// setelah berpindah session).
  int? actionFormId;

  /// True bila aksi pernah dijalankan (diterima) — tanpa ini, setelah
  /// restart app tombol Undo / chip status / Buka Form hilang.
  bool? actionExecuted;

  /// True bila bubble ini pesan error (agar gaya error tetap setelah restart).
  bool? isError;

  /// Snapshot untuk undo + status undo (lihat ChatMessage.undoSnapshot).
  Map<String, dynamic>? undoSnapshot;
  bool? actionUndone;

  ChatHistoryMessage({
    required this.role,
    required this.text,
    this.actionJson,
    this.actionStatus,
    this.actionResult,
    this.actionFormId,
    this.actionExecuted,
    this.isError,
    this.undoSnapshot,
    this.actionUndone,
  });
  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'actionJson': actionJson,
        'actionStatus': actionStatus,
        'actionResult': actionResult,
        'actionFormId': actionFormId,
        'actionExecuted': actionExecuted,
        'isError': isError,
        'undoSnapshot': undoSnapshot,
        'actionUndone': actionUndone,
      };
  factory ChatHistoryMessage.fromJson(Map<String, dynamic> j) =>
      ChatHistoryMessage(
        role: j['role'] as String,
        text: j['text'] as String,
        actionJson: j['actionJson'] as Map<String, dynamic>?,
        actionStatus: j['actionStatus'] as String?,
        actionResult: j['actionResult'] as String?,
        actionFormId: j['actionFormId'] as int?,
        actionExecuted: j['actionExecuted'] as bool?,
        isError: j['isError'] as bool?,
        undoSnapshot: j['undoSnapshot'] as Map<String, dynamic>?,
        actionUndone: j['actionUndone'] as bool?,
      );
}

class ChatSession {
  final String id;
  String title;
  List<ChatHistoryMessage> messages;
  DateTime updatedAt;

  /// Konteks form terakhir (hasil @mention) di sesi ini — dibawa ulang ke
  /// pesan lanjutan agar AI tetap punya id soal untuk aksi edit/hapus.
  String? formContext;

  /// Form aktif sesi: dibuat AI (aksi diterima) atau terakhir di-mention
  /// user. Pesan lanjutan otomatis memakai konteks form ini.
  int? activeFormId;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    DateTime? updatedAt,
    this.formContext,
    this.activeFormId,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
        'formContext': formContext,
        'activeFormId': activeFormId,
      };
  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Chat',
        messages: (j['messages'] as List<dynamic>? ?? [])
            .map((e) => ChatHistoryMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        updatedAt: j['updatedAt'] != null
            ? DateTime.tryParse(j['updatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        formContext: j['formContext'] as String?,
        activeFormId: j['activeFormId'] as int?,
      );
}

class AiChatHistoryService {
  static const _key = 'ai_chat_history_v1';

  static Future<List<ChatSession>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ChatSession.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(sessions.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  static Future<void> upsert(ChatSession session) async {
    final all = await loadAll();
    final idx = all.indexWhere((e) => e.id == session.id);
    if (idx >= 0) {
      all[idx] = session;
    } else {
      all.insert(0, session);
    }
    await saveAll(all);
  }

  static Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    await saveAll(all);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
