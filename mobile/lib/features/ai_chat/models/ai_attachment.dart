import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Lampiran untuk pesan AI — hidup di memori dengan bytes,
/// tapi saat dipersist hanya metadata yang disimpan (bytes tidak ikut SharedPreferences).
/// Bytes disimpan ke disk (folder support `ai_chat_attachments`) lewat
/// [saveToDisk]; path-nya ikut metadata sehingga preview gambar tetap
/// bisa dibuka setelah restart / ganti sesi via [reloadBytes].
class AiAttachment {
  final String id;
  final String name;
  final String mime;
  final int sizeBytes;
  Uint8List bytes;

  /// Path file di disk (diisi setelah [saveToDisk] / dari metadata riwayat).
  String? filePath;

  AiAttachment({
    required this.id,
    required this.name,
    required this.mime,
    required this.sizeBytes,
    required this.bytes,
    this.filePath,
  });

  String get base64Data => base64Encode(bytes);

  bool get isImage => mime.startsWith('image/');
  bool get isPdf => mime == 'application/pdf';
  bool get isDoc =>
      mime == 'application/msword' ||
      mime == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  bool get isExcel =>
      mime == 'application/vnd.ms-excel' ||
      mime == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Previewable via Image.memory (Flutter tidak bisa decode HEIC/HEIF di Windows/Android)
  bool get isPreviewableImage =>
      mime == 'image/png' || mime == 'image/jpeg' || mime == 'image/webp';

  Map<String, dynamic> toMetaJson() => {
        'id': id,
        'name': name,
        'mime': mime,
        'sizeBytes': sizeBytes,
        if (filePath != null && filePath!.isNotEmpty) 'filePath': filePath,
      };

  static AiAttachment? tryFromMeta(Map<String, dynamic> j) {
    try {
      final name = j['name']?.toString() ?? '';
      if (name.isEmpty) return null;
      final fp = j['filePath']?.toString() ?? '';
      return AiAttachment(
        id: j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        mime: j['mime']?.toString() ?? 'application/octet-stream',
        sizeBytes: j['sizeBytes'] is int ? j['sizeBytes'] as int : int.tryParse('${j['sizeBytes']}') ?? 0,
        bytes: Uint8List(0), // diisi ulang via reloadBytes() bila file ada
        filePath: (fp.isEmpty) ? null : fp,
      );
    } catch (_) {
      return null;
    }
  }

  /// Simpan bytes lampiran ke disk (folder support app) — sekali saja
  /// per lampiran (dipanggil saat persist riwayat). Kembalikan path
  /// file, atau null bila gagal (best-effort, jangan ganggu chat).
  static Future<String?> saveToDisk(AiAttachment a) async {
    if (!a.hasBytes) return a.filePath;
    try {
      final dir = await getApplicationSupportDirectory();
      final folder = Directory(
          '${dir.path}${Platform.pathSeparator}ai_chat_attachments');
      if (!await folder.exists()) await folder.create(recursive: true);
      final safeName = a.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${folder.path}${Platform.pathSeparator}${a.id}_$safeName');
      await file.writeAsBytes(a.bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Muat ulang bytes dari [filePath] (dipakai saat sesi dibuka dari
  /// riwayat — metadata saja tidak membawa bytes). Best-effort: file
  /// hilang/korup dibiarkan kosong, chip tetap tampil tanpa preview.
  Future<void> reloadBytes() async {
    if (bytes.isNotEmpty) return;
    final p = filePath;
    if (p == null || p.isEmpty) return;
    try {
      final f = File(p);
      if (await f.exists()) {
        bytes = await f.readAsBytes();
      }
    } catch (_) {}
  }

  bool get hasBytes => bytes.isNotEmpty;

  /// Mime dari ekstensi file
  static String mimeFromExtension(String ext) {
    final e = ext.toLowerCase().replaceAll('.', '');
    switch (e) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'application/octet-stream';
    }
  }

  /// Ekstensi diperbolehkan
  static const allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'png',
    'jpg',
    'jpeg',
    'webp',
    'heic',
    'heif',
  ];

  /// Batas: 3 file @20MB
  static const maxCount = 3;
  static const maxBytesPerFile = 20 * 1024 * 1024;

  /// Gemini inlineData dukung image + pdf langsung; doc/excel dikonversi ke teks
  static bool isInlineSupported(String mime) {
    return mime.startsWith('image/') || mime == 'application/pdf';
  }
}
