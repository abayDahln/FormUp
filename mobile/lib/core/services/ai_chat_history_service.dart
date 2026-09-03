import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatHistoryMessage {
  final String role;
  String text;
  ChatHistoryMessage({required this.role, required this.text});
  Map<String, dynamic> toJson() => {'role': role, 'text': text};
  factory ChatHistoryMessage.fromJson(Map<String, dynamic> j) => ChatHistoryMessage(role: j['role'] as String, text: j['text'] as String);
}

class ChatSession {
  final String id;
  String title;
  List<ChatHistoryMessage> messages;
  DateTime updatedAt;
  ChatSession({required this.id, required this.title, required this.messages, DateTime? updatedAt}) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };
  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Chat',
        messages: (j['messages'] as List<dynamic>? ?? []).map((e) => ChatHistoryMessage.fromJson(e as Map<String, dynamic>)).toList(),
        updatedAt: j['updatedAt'] != null ? DateTime.tryParse(j['updatedAt'] as String) ?? DateTime.now() : DateTime.now(),
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
