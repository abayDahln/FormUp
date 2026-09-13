import 'dart:convert';
import 'dart:typed_data';

/// Lampiran untuk pesan AI — hidup di memori dengan bytes,
/// tapi saat dipersist hanya metadata yang disimpan (bytes tidak ikut SharedPreferences).
class AiAttachment {
  final String id;
  final String name;
  final String mime;
  final int sizeBytes;
  final Uint8List bytes;

  const AiAttachment({
    required this.id,
    required this.name,
    required this.mime,
    required this.sizeBytes,
    required this.bytes,
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
      };

  static AiAttachment? tryFromMeta(Map<String, dynamic> j) {
    try {
      final name = j['name']?.toString() ?? '';
      if (name.isEmpty) return null;
      return AiAttachment(
        id: j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        mime: j['mime']?.toString() ?? 'application/octet-stream',
        sizeBytes: j['sizeBytes'] is int ? j['sizeBytes'] as int : int.tryParse('${j['sizeBytes']}') ?? 0,
        bytes: Uint8List(0), // placeholder — riwayat tidak menyimpan bytes
      );
    } catch (_) {
      return null;
    }
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

  /// Batas: 3 file @10MB
  static const maxCount = 3;
  static const maxBytesPerFile = 10 * 1024 * 1024;

  /// Gemini inlineData dukung image + pdf langsung; doc/excel dikonversi ke teks
  static bool isInlineSupported(String mime) {
    return mime.startsWith('image/') || mime == 'application/pdf';
  }
}
