import 'package:flutter/foundation.dart';

/// Satu bubble chat AI (user | model).
class ChatMessage {
  final String role; // user | model
  String text;
  final DateTime time;
  Map<String, dynamic>? actionJson;

  /// Status aksi form yang diajukan AI di bubble ini:
  /// '' (bukan/legacy) | 'pending' | 'accepted' | 'rejected'.
  String actionStatus = '';
  bool actionExecuted = false;
  String? actionResult;

  /// Form yang terlibat aksi (diisi setelah aksi diterima & berhasil) —
  /// dipakai tombol "Buka Form" di bawah bubble untuk navigasi ke detail.
  int? actionFormId;

  /// True bila bubble ini berisi pesan error (tampilkan gaya error + tombol coba lagi).
  bool isError = false;

  /// True bila bubble ini mengajukan aksi form yang belum diterima/ditolak.
  bool get hasPendingAction => actionJson != null && actionStatus == 'pending';

  /// Non-null hanya selama bubble ini sedang di-stream: chunk terbaru
  /// ditulis ke [stream] agar HANYA bubble ini yang rebuild
  /// (via ValueListenableBuilder), bukan seluruh ListView.
  ValueNotifier<String>? stream;

  ChatMessage({
    required this.role,
    required this.text,
    DateTime? time,
    this.actionJson,
  }) : time = time ?? DateTime.now();

  void disposeStream() {
    stream?.dispose();
    stream = null;
  }
}
