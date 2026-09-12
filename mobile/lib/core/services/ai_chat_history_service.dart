import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:form_up/core/services/auth_service.dart';

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

  /// True bila respons terpotong (agar tombol Lanjutkan tetap setelah restart).
  bool? isTruncated;

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
    this.isTruncated,
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
        'isTruncated': isTruncated,
        'undoSnapshot': undoSnapshot,
        'actionUndone': actionUndone,
      };
  /// Parse toleran: nilai bertipe salah (mis. int tersimpan sebagai
  /// String karena versi lama/disk korup) dikonversi bila mungkin,
  /// bukan melempar — pemanggil melewati pesan yang tetap tak valid.
  factory ChatHistoryMessage.fromJson(Map<String, dynamic> j) {
    int? asInt(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    bool? asBool(Object? v) {
      if (v == null) return null;
      if (v is bool) return v;
      final s = v.toString().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
      return null;
    }

    Map<String, dynamic>? asMap(Object? v) {
      if (v == null) return null;
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    return ChatHistoryMessage(
      role: j['role'] as String? ?? 'model',
      text: j['text']?.toString() ?? '',
      actionJson: asMap(j['actionJson']),
      actionStatus: j['actionStatus']?.toString(),
      actionResult: j['actionResult']?.toString(),
      actionFormId: asInt(j['actionFormId']),
      actionExecuted: asBool(j['actionExecuted']),
      isError: asBool(j['isError']),
      isTruncated: asBool(j['isTruncated']),
      undoSnapshot: asMap(j['undoSnapshot']),
      actionUndone: asBool(j['actionUndone']),
    );
  }

  /// Null bila pesan tak bisa dipakai sama sekali (bukan Map).
  /// Dipakai loadAll agar 1 bubble rusak tak menghapus seluruh riwayat.
  static ChatHistoryMessage? tryFromJson(Object? e) {
    if (e is! Map) return null;
    try {
      final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e);
      // Syarat minimal: role & text masih bisa dibaca.
      if (m['role'] == null && m['text'] == null) return null;
      return ChatHistoryMessage.fromJson(m);
    } catch (_) {
      return null;
    }
  }
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
  factory ChatSession.fromJson(Map<String, dynamic> j) {
    // Pesan rusak dilewati satu per satu — JANGAN gagalkan seluruh sesi.
    final messages = <ChatHistoryMessage>[];
    for (final e in (j['messages'] as List<dynamic>? ?? [])) {
      final m = ChatHistoryMessage.tryFromJson(e);
      if (m != null) messages.add(m);
    }
    final rawActive = j['activeFormId'];
    return ChatSession(
      id: j['id']?.toString() ?? '',
      title: j['title'] as String? ?? 'Chat',
      messages: messages,
      updatedAt: j['updatedAt'] != null
          ? DateTime.tryParse(j['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      formContext: j['formContext']?.toString(),
      activeFormId:
          rawActive is int ? rawActive : int.tryParse('${rawActive ?? ''}'),
    );
  }
}

class AiChatHistoryService {
  static const _legacyKey = 'ai_chat_history_v1';

  /// Penanda migrasi legacy sudah pernah diputuskan (sekali per perangkat).
  /// Tanpa ini, data global lama bisa "diadopsi" akun yang salah bila
  /// akun pertama login setelah update dan akun lain memakai perangkat.
  static const _migratedFlag = 'ai_chat_history_migrated_v1';

  /// Key penyimpanan per-akun agar chat tidak bocor lintas akun.
  /// Tanpa accountId (belum login) → key legacy bersama.
  static String _keyFor(String? accountId) {
    final id = (accountId ?? AuthService.email ?? '').trim().toLowerCase();
    if (id.isEmpty) return _legacyKey;
    return '$_legacyKey::$id';
  }

  /// Pindahkan data key global lama ke key akun saat ini — tepat SEKALI
  /// per perangkat. Bila akun sudah punya data sendiri, atau keputusan
  /// migrasi sudah pernah diambil, legacy TIDAK disentuh (bukan milik
  /// akun ini — kemungkinan sisa versi lama).
  static Future<void> _migrateLegacy(String key) async {
    if (key == _legacyKey) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedFlag) == true) return;
    if (prefs.getString(key) != null) {
      await prefs.setBool(_migratedFlag, true);
      return;
    }
    final legacy = prefs.getString(_legacyKey);
    if (legacy == null || legacy.isEmpty) {
      await prefs.setBool(_migratedFlag, true);
      return;
    }
    await prefs.setString(key, legacy);
    await prefs.remove(_legacyKey);
    await prefs.setBool(_migratedFlag, true);
  }

  static Future<List<ChatSession>> loadAll({String? accountId}) async {
    final key = _keyFor(accountId);
    await _migrateLegacy(key);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final sessions = <ChatSession>[];
      for (final e in list) {
        try {
          if (e is! Map) continue;
          final m = e is Map<String, dynamic>
              ? e
              : Map<String, dynamic>.from(e);
          // Sesi tanpa id valid dilewati (bukan gagalkan semua).
          if ((m['id']?.toString() ?? '').isEmpty) continue;
          sessions.add(ChatSession.fromJson(m));
        } catch (_) {
          // 1 sesi rusak → lewati, riwayat lain tetap selamat.
        }
      }
      return sessions..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<ChatSession> sessions, {String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(sessions.map((e) => e.toJson()).toList());
    await prefs.setString(_keyFor(accountId), raw);
  }

  static Future<void> upsert(ChatSession session, {String? accountId}) async {
    final all = await loadAll(accountId: accountId);
    final idx = all.indexWhere((e) => e.id == session.id);
    if (idx >= 0) {
      all[idx] = session;
    } else {
      all.insert(0, session);
    }
    await saveAll(all, accountId: accountId);
  }

  static Future<void> delete(String id, {String? accountId}) async {
    final all = await loadAll(accountId: accountId);
    all.removeWhere((e) => e.id == id);
    await saveAll(all, accountId: accountId);
  }

  static Future<void> clearAll({String? accountId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(accountId));
  }
}
