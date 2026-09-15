import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:form_up/features/ai_chat/models/ai_attachment.dart';

/// Hasil fetch satu URL: konteks teks (halaman web) ATAU attachment file
/// (pdf/gambar langsung) yang bisa langsung masuk jalur lampiran chat.
class UrlFetchResult {
  final String? textContext;
  final AiAttachment? attachment;

  const UrlFetchResult.text(this.textContext) : attachment = null;
  const UrlFetchResult.file(this.attachment) : textContext = null;
}

final _urlRegex =
    RegExp(r'https?:\/\/[^\s<>"\)\]]+', caseSensitive: false);

/// Ambil semua URL dari teks prompt (unik, urut sesuai kemunculan).
List<String> extractUrls(String text) {
  final seen = <String>{};
  final out = <String>[];
  for (final m in _urlRegex.allMatches(text)) {
    // Buang tanda baca di ujung (mis. "... link." → tanpa titik).
    final cleaned = (m.group(0) ?? '').replaceAll(RegExp(r'[.,;:!?]+$'), '');
    if (cleaned.isEmpty) continue;
    if (Uri.tryParse(cleaned)?.hasScheme ?? false) {
      if (seen.add(cleaned)) out.add(cleaned);
    }
  }
  return out;
}

const _maxBytes = 2 * 1024 * 1024; // 2MB teks halaman
const _maxTextChars = 8000; // batas teks konteks per URL

/// Fetch isi URL: halaman web → teks polos; PDF/gambar → AiAttachment
/// (ikut jalur lampiran: preview chip di chat + inlineData ke Gemini).
/// Return null bila gagal (offline, 404, ukuran kebesaran, konten tak terbaca).
Future<UrlFetchResult?> fetchUrlContext(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return null;
  try {
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final bytes = res.bodyBytes;
    if (bytes.isEmpty) return null;
    final mime = (res.headers['content-type'] ?? '')
        .split(';')
        .first
        .trim()
        .toLowerCase();

    if (mime.startsWith('image/') || mime == 'application/pdf') {
      if (bytes.length > AiAttachment.maxBytesPerFile) return null;
      final name = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : (mime.startsWith('image/') ? 'image' : 'document.pdf');
      return UrlFetchResult.file(AiAttachment(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        mime: mime.startsWith('image/') ? mime : 'application/pdf',
        sizeBytes: bytes.length,
        bytes: bytes,
      ));
    }

    // Teks: HTML atau plain text.
    var body = utf8.decode(bytes, allowMalformed: true);
    if (bytes.length > _maxBytes) {
      body = body.substring(0, _maxBytes ~/ 2);
    }
    final isHtml = mime.contains('html') ||
        RegExp(r'<html|<body|<div|<p[\s>]', caseSensitive: false)
            .hasMatch(body);
    if (isHtml) body = _htmlToText(body);
    body = body.trim();
    if (body.isEmpty) return null;
    if (body.length > _maxTextChars) {
      body = '${body.substring(0, _maxTextChars)}... (dipotong)';
    }
    return UrlFetchResult.text(body);
  } catch (_) {
    return null;
  }
}

/// Sederhana: buang script/style/komentar, ubah tag jadi spasi/newline,
/// decode entity umum, lalu rapikan whitespace. Cukup untuk konteks AI.
String _htmlToText(String html) {
  var s = html;
  final title = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
      .firstMatch(s)
      ?.group(1);
  s = s.replaceAll(
      RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ');
  s = s.replaceAll(
      RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ');
  s = s.replaceAll(
      RegExp(r'<noscript[\s\S]*?</noscript>', caseSensitive: false), ' ');
  s = s.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ');
  s = s.replaceAll(
      RegExp(r'<(br|/p|/div|/h[1-6]|/li|/tr)\s*/?>', caseSensitive: false),
      '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
  s = _decodeEntities(s);
  s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
  s = s
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .join('\n');
  if (title != null && title.trim().isNotEmpty) {
    s = '${title.trim()}\n$s';
  }
  return s;
}

String _decodeEntities(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'");
