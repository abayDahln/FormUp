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
