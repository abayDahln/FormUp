import 'dart:convert';

/// Parse JSON aksi AI yang toleran terhadap teks pengiring.
///
/// Masalah yang diatasi: AI sering menambahkan teks SETELAH objek JSON
/// (mis. "LANJUT: masih ada X soal") — kadang di dalam pagar code fence —
/// sehingga parse fence-mentah gagal dan preview/aksi hilang.
///
/// Strategi: cari kandidat objek `{...}` yang seimbang (brace matching
/// sadar-string/escape), decode, ambil yang pertama mengandung key "action".
/// Teks sebelum/sesudah objek diabaikan.
Map<String, dynamic>? parseActionJson(String text) {
  // 1) Coba tiap blok ```json (tertutup maupun menggantung).
  final fenceStarts = <int>[];
  final fenceRe = RegExp(r'```json', caseSensitive: false);
  for (final m in fenceRe.allMatches(text)) {
    fenceStarts.add(m.end);
  }
  for (final start in fenceStarts) {
    final found = _firstBalancedObject(text, start);
    if (found != null) return found;
  }
  // 2) Fallback: pindai seluruh teks.
  return _firstBalancedObject(text, 0);
}

/// Kembalikan Map pertama ber-key "action" dari objek JSON seimbang
/// yang diawali pada/after [from], atau null.
Map<String, dynamic>? _firstBalancedObject(String text, int from) {
  var i = text.indexOf('{', from);
  while (i >= 0) {
    final end = _balancedEnd(text, i);
    if (end > i) {
      try {
        final decoded = jsonDecode(text.substring(i, end));
        if (decoded is Map<String, dynamic> && decoded['action'] != null) {
          return decoded;
        }
      } catch (_) {
        // Lanjut cari kandidat berikutnya.
      }
      i = text.indexOf('{', i + 1);
    } else {
      // Tak seimbang dari sini — coba mulai dari '{' berikutnya
      // (berguna bila objek terpotong tapi ada objek valid sesudahnya).
      i = text.indexOf('{', i + 1);
    }
  }
  return null;
}

/// Index tepat SETELAH '}' yang menutup objek dibuka di [openIndex],
/// sadar string ("...") + escape (\\). -1 bila tak seimbang.
int _balancedEnd(String text, int openIndex) {
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = openIndex; i < text.length; i++) {
    final c = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (c == '\\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    if (c == '"') {
      inString = true;
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return -1;
}

/// True bila teks mengandung pagar ```json yang tak tertutup.
bool hasUnclosedJsonFence(String text) {
  final opens =
      RegExp(r'```json', caseSensitive: false).allMatches(text).length;
  if (opens == 0) return false;
  final fences = '```'.allMatches(text).length;
  return fences <= opens;
}

/// Hasil ekstraksi progresif untuk preview streaming: soal-soal yang
/// objek JSON-nya SUDAH lengkap + info apakah ada objek yang masih jalan.
class StreamingQuestions {
  final String? action;
  final List<Map<String, dynamic>> questions;
  final bool hasOpenObject;

  const StreamingQuestions({
    this.action,
    this.questions = const [],
    this.hasOpenObject = false,
  });
}

/// Panen objek soal lengkap dari buffer stream yang terus bertambah.
/// Hanya melihat di dalam blok ```json pertama (teks prosa diabaikan),
/// sehingga aman dipanggil tiap tick. Murah: berhenti di objek tak lengkap.
StreamingQuestions extractStreamingQuestions(String text) {
  var scope = text;
  final fence = RegExp(r'```json', caseSensitive: false).firstMatch(text);
  if (fence == null) return const StreamingQuestions();
  scope = text.substring(fence.end);
  // Bila pagar penutup sudah ada, batasi di situ (respons selesai).
  final closeIdx = scope.indexOf('```');
  final body = closeIdx >= 0 ? scope.substring(0, closeIdx) : scope;

  String? action;
  final actionMatch =
      RegExp(r'"action"\s*:\s*"([A-Za-z_]+)"').firstMatch(body);
  if (actionMatch != null) action = actionMatch.group(1);

  final qKey = RegExp(r'"questions"\s*:').firstMatch(body);
  if (qKey == null) return StreamingQuestions(action: action);
  final arrStart = body.indexOf('[', qKey.end);
  if (arrStart < 0) return StreamingQuestions(action: action);

  final questions = <Map<String, dynamic>>[];
  var hasOpen = false;
  var i = arrStart + 1;
  while (i < body.length) {
    final c = body[i];
    if (c == ' ' ||
        c == '\n' ||
        c == '\r' ||
        c == '\t' ||
        c == ',') {
      i++;
      continue;
    }
    if (c == ']') break; // array selesai
    if (c != '{') {
      i++; // toleran terhadap karakter asing
      continue;
    }
    final end = _balancedEnd(body, i);
    if (end < 0) {
      hasOpen = true; // objek masih ditulis model
      break;
    }
    try {
      final decoded = jsonDecode(body.substring(i, end));
      if (decoded is Map<String, dynamic>) questions.add(decoded);
    } catch (_) {
      hasOpen = true; // rusak/di tengah escape — anggap masih jalan
      break;
    }
    i = end;
  }
  return StreamingQuestions(
    action: action,
    questions: questions,
    hasOpenObject: hasOpen,
  );
}
