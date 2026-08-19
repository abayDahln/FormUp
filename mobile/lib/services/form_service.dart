import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Sinyal agar layar daftar form/beranda me-refresh setelah form dibuat/diubah.
final ValueNotifier<int> formsVersion = ValueNotifier(0);

/// Batas maksimal upload media soal/banner (sama dengan server).
const int kMaxUploadBytes = 10 * 1024 * 1024;

/// true bila ukuran file melebihi batas upload (10 MB).
bool exceedsUploadLimit(Uint8List bytes) => bytes.length > kMaxUploadBytes;

/// Model form
class FormData {
  final int id;
  final String title;
  final String? description;
  final String? bannerImage;
  final String formLink;
  final String status;
  final int responseCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FormData({
    required this.id,
    required this.title,
    required this.formLink,
    required this.status,
    this.description,
    this.bannerImage,
    this.responseCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory FormData.fromJson(Map<String, dynamic> json) {
    final raw = json['updatedAt'] as String?;
    final rawCreated = json['createdAt'] as String?;
    return FormData(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      bannerImage: json['bannerImage'] as String?,
      formLink: json['formLink'] as String? ?? '',
      status: (json['status'] as String? ?? 'draft').toLowerCase(),
      responseCount: json['responseCount'] as int? ?? 0,
      createdAt: rawCreated == null || rawCreated.isEmpty
          ? null
          : DateTime.tryParse(rawCreated),
      updatedAt: raw == null || raw.isEmpty ? null : DateTime.tryParse(raw),
    );
  }
}

/// Opsi pertanyaan
class QuestionOptionData {
  final int? id;
  final String optionText;
  final bool? isCorrect;

  const QuestionOptionData({this.id, required this.optionText, this.isCorrect});
}

/// Pertanyaan lengkap
class QuestionData {
  final int id;
  final int typeId;
  final String question;
  final int questionOrder;
  final String? questionImage;
  final String? questionAudio;
  final bool? isRequired;
  final String? correctAnswer;
  final bool? randomizeOptions;
  final List<QuestionOptionData> options;

  const QuestionData({
    required this.id,
    required this.typeId,
    required this.question,
    required this.questionOrder,
    this.questionImage,
    this.questionAudio,
    this.isRequired,
    this.correctAnswer,
    this.randomizeOptions,
    this.options = const [],
  });

  factory QuestionData.fromJson(Map<String, dynamic> json) => QuestionData(
        id: json['id'] as int,
        typeId: json['typeId'] as int,
        question: json['question'] as String? ?? '',
        questionOrder: json['questionOrder'] as int? ?? 0,
        questionImage: json['questionImage'] as String?,
        questionAudio: json['questionAudio'] as String?,
        isRequired: json['isRequired'] as bool?,
        correctAnswer: json['correctAnswer'] as String?,
        randomizeOptions: json['randomizeOptions'] as bool?,
        options: [
          for (final o in json['options'] as List<dynamic>? ?? [])
            QuestionOptionData(
              id: o['id'] as int?,
              optionText: o['optionText'] as String? ?? '',
              isCorrect: o['isCorrect'] as bool?,
            ),
        ],
      );
}

/// Item riwayat form
class MyResponseItem {  final int responseId;
  final int formId;
  final String formTitle;
  final String formLink;
  final String status;
  final DateTime? submittedAt;

  const MyResponseItem({
    required this.responseId,
    required this.formId,
    required this.formTitle,
    required this.formLink,
    required this.status,
    this.submittedAt,
  });

  factory MyResponseItem.fromJson(Map<String, dynamic> json) {
    final raw = json['submittedAt'] as String?;
    return MyResponseItem(
      responseId: json['responseId'] as int,
      formId: json['formId'] as int,
      formTitle: json['formTitle'] as String? ?? '',
      formLink: json['formLink'] as String? ?? '',
      status: json['status'] as String? ?? 'new',
      submittedAt: raw == null ? null : DateTime.tryParse(raw),
    );
  }
}

/// Analisis respons form
class FormAnalytics {
  final int totalResponses;
  final int totalQuestions;
  final int scorableQuestions;
  final double? averageScore;
  final List<RespondentAnalyticsData> respondents;

  const FormAnalytics({
    this.totalResponses = 0,
    this.totalQuestions = 0,
    this.scorableQuestions = 0,
    this.averageScore,
    this.respondents = const [],
  });

  factory FormAnalytics.fromJson(Map<String, dynamic> json) => FormAnalytics(
        totalResponses: json['totalResponses'] as int? ?? 0,
        totalQuestions: json['totalQuestions'] as int? ?? 0,
        scorableQuestions: json['scorableQuestions'] as int? ?? 0,
        averageScore: (json['averageScore'] as num?)?.toDouble(),
        respondents: [
          for (final r in json['respondents'] as List<dynamic>? ?? [])
            RespondentAnalyticsData.fromJson(r as Map<String, dynamic>),
        ],
      );
}

class RespondentAnalyticsData {
  final int responseId;
  final String? respondentName;
  final DateTime submittedAt;
  final int answeredCount;
  final int totalQuestions;
  final int correctCount;
  final int scorableQuestions;
  final double? score;
  final List<AnswerAnalyticsData> answers;

  const RespondentAnalyticsData({
    required this.responseId,
    this.respondentName,
    required this.submittedAt,
    this.answeredCount = 0,
    this.totalQuestions = 0,
    this.correctCount = 0,
    this.scorableQuestions = 0,
    this.score,
    this.answers = const [],
  });

  factory RespondentAnalyticsData.fromJson(Map<String, dynamic> json) {
    final raw = json['submittedAt'] as String?;
    return RespondentAnalyticsData(
      responseId: json['responseId'] as int,
      respondentName: json['respondentName'] as String?,
      submittedAt: raw == null ? DateTime.now() : DateTime.tryParse(raw) ?? DateTime.now(),
      answeredCount: json['answeredCount'] as int? ?? 0,
      totalQuestions: json['totalQuestions'] as int? ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
      scorableQuestions: json['scorableQuestions'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble(),
      answers: [
        for (final a in json['answers'] as List<dynamic>? ?? [])
          AnswerAnalyticsData.fromJson(a as Map<String, dynamic>),
      ],
    );
  }
}

class AnswerAnalyticsData {
  final int questionId;
  final String question;
  final int typeId;
  final String? answerText;
  final String? correctAnswer;
  final bool? isCorrect;

  const AnswerAnalyticsData({
    required this.questionId,
    required this.question,
    required this.typeId,
    this.answerText,
    this.correctAnswer,
    this.isCorrect,
  });

  factory AnswerAnalyticsData.fromJson(Map<String, dynamic> json) =>
      AnswerAnalyticsData(
        questionId: json['questionId'] as int,
        question: json['question'] as String? ?? '',
        typeId: json['typeId'] as int,
        answerText: json['answerText'] as String?,
        correctAnswer: json['correctAnswer'] as String?,
        isCorrect: json['isCorrect'] as bool?,
      );
}

/// Item respons
class ResponseListItemData {
  final int id;
  final String? respondentName;
  final String status;
  final DateTime? submittedAt;

  const ResponseListItemData({
    required this.id,
    this.respondentName,
    this.status = 'new',
    this.submittedAt,
  });

  factory ResponseListItemData.fromJson(Map<String, dynamic> json) {
    final raw = json['submittedAt'] as String?;
    return ResponseListItemData(
      id: json['id'] as int,
      respondentName: json['respondentName'] as String?,
      status: json['status'] as String? ?? 'new',
      submittedAt: raw == null ? null : DateTime.tryParse(raw),
    );
  }
}

/// Jawaban detail respons
class ResponseAnswerDetailData {
  final int questionId;
  final String question;
  final int typeId;
  final String? optionText;
  final String? answerValue;

  const ResponseAnswerDetailData({
    required this.questionId,
    required this.question,
    required this.typeId,
    this.optionText,
    this.answerValue,
  });

  factory ResponseAnswerDetailData.fromJson(Map<String, dynamic> json) =>
      ResponseAnswerDetailData(
        questionId: json['questionId'] as int,
        question: json['question'] as String? ?? '',
        typeId: json['typeId'] as int? ?? 0,
        optionText: json['optionText'] as String?,
        answerValue: json['answerValue'] as String?,
      );

  String get display =>
      (optionText?.isNotEmpty ?? false) ? optionText! : (answerValue ?? '');
}

/// Detail respons
class ResponseDetailData {
  final int id;
  final String? respondentName;
  final String status;
  final DateTime? submittedAt;
  final List<ResponseAnswerDetailData> answers;

  const ResponseDetailData({
    required this.id,
    this.respondentName,
    this.status = 'new',
    this.submittedAt,
    this.answers = const [],
  });

  factory ResponseDetailData.fromJson(Map<String, dynamic> json) {
    final raw = json['submittedAt'] as String?;
    return ResponseDetailData(
      id: json['id'] as int,
      respondentName: json['respondentName'] as String?,
      status: json['status'] as String? ?? 'new',
      submittedAt: raw == null ? null : DateTime.tryParse(raw),
      answers: [
        for (final a in json['answers'] as List<dynamic>? ?? [])
          ResponseAnswerDetailData.fromJson(a as Map<String, dynamic>),
      ],
    );
  }
}

/// Hasil berpaginasi
class PagedResult<T> {
  final List<T> items;
  final int total;

  const PagedResult({required this.items, required this.total});
}

/// Klien forms & questions
class FormService {
  /// POST /forms
  static Future<int> createForm({
    required String title,
    String? description,
  }) async {
    final json = await AuthService.post('/forms', {
      'title': title,
      'description': description,
    });
    final data = json['data'] as Map<String, dynamic>;
    return data['id'] as int;
  }

  /// GET /forms/{id}
  static Future<Map<String, dynamic>> getForm(int id) async {
    final json = await AuthService.get('/forms/$id');
    return json['data'] as Map<String, dynamic>;
  }

  /// GET /forms
  static Future<List<FormData>> getMyForms() async {
    final json = await AuthService.get('/forms');
    return [
      for (final f in json['data'] as List<dynamic>? ?? [])
        FormData.fromJson(f as Map<String, dynamic>),
    ];
  }

  /// PUT /forms/{id}
  static Future<void> updateForm(
    int id, {
    String? title,
    String? description,
    String? formLink,
    String? bannerImage,
  }) async {
    await AuthService.put('/forms/$id', {
      'title': ?title,
      'description': ?description,
      'formLink': ?formLink,
      'bannerImage': ?bannerImage,
    });
  }

  /// PATCH /forms/{id}/settings
  static Future<void> updateSettings(int id, Map<String, dynamic> settings) =>
      AuthService.patch('/forms/$id/settings', settings);

  /// GET /forms/{id}/questions
  static Future<List<QuestionData>> getQuestions(int formId) async {
    final json = await AuthService.get('/forms/$formId/questions');
    return [
      for (final q in json['data'] as List<dynamic>? ?? [])
        QuestionData.fromJson(q as Map<String, dynamic>),
    ];
  }

  /// POST /forms/{id}/questions
  /// Mengembalikan daftar soal yang dibuat (berisi id) — dipakai upload media.
  static Future<List<Map<String, dynamic>>> saveQuestions(
    int formId,
    List<Map<String, dynamic>> questions,
  ) async {
    final json = await AuthService.post('/forms/$formId/questions', {
      'questions': questions,
    });
    return [
      for (final q in json['data'] as List<dynamic>? ?? [])
        (q as Map<String, dynamic>),
    ];
  }

  /// PUT /forms/{id}/questions
  /// Mengembalikan daftar soal yang disimpan (berisi id).
  static Future<List<Map<String, dynamic>>> updateQuestions(
    int formId,
    List<Map<String, dynamic>> questions,
  ) async {
    final json = await AuthService.put('/forms/$formId/questions', {
      'questions': questions,
    });
    return [
      for (final q in json['data'] as List<dynamic>? ?? [])
        (q as Map<String, dynamic>),
    ];
  }

  /// POST /forms/{id}/publish
  static Future<void> publish(int formId) async {
    await AuthService.post('/forms/$formId/publish', {});
  }

  /// DELETE /forms/{id}
  static Future<void> deleteForm(int id) => AuthService.delete('/forms/$id');

  /// GET /users/me/responses
  static Future<List<MyResponseItem>> getMyResponses() async {
    final json = await AuthService.get('/users/me/responses');
    return [
      for (final r in json['data'] as List<dynamic>? ?? [])
        MyResponseItem.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// GET /forms/{id}/responses
  static Future<PagedResult<ResponseListItemData>> getResponses(
    int formId, {
    int? page,
    int? pageSize,
  }) async {
    final path = page != null && pageSize != null
        ? '/forms/$formId/responses?page=$page&pageSize=$pageSize'
        : '/forms/$formId/responses';
    final json = await AuthService.get(path);
    final data = json['data'];

    // Backward-compat: tanpa param server mengembalikan array polos.
    if (data is List) {
      return PagedResult(
        items: [
          for (final r in data) ResponseListItemData.fromJson(r as Map<String, dynamic>),
        ],
        total: data.length,
      );
    }
    final map = data as Map<String, dynamic>;
    return PagedResult(
      items: [
        for (final r in map['items'] as List<dynamic>? ?? [])
          ResponseListItemData.fromJson(r as Map<String, dynamic>),
      ],
      total: map['total'] as int? ?? 0,
    );
  }

  /// GET /forms/{id}/responses/{responseId}
  static Future<ResponseDetailData> getResponseDetail(
    int formId,
    int responseId,
  ) async {
    final json = await AuthService.get('/forms/$formId/responses/$responseId');
    return ResponseDetailData.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// PUT /responses/{id}/status
  static Future<void> updateResponseStatus(int responseId, int statusId) =>
      AuthService.put('/responses/$responseId/status', {'statusId': statusId});

  /// POST /forms/{id}/feedback
  static Future<void> submitFeedback(
    int formId, {
    required String reason,
    String? description,
  }) async {
    await AuthService.post('/forms/$formId/feedback', {
      'reason': reason,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
  }

  /// GET /forms/{id}/analytics
  static Future<FormAnalytics> getAnalytics(
    int formId, {
    int? page,
    int? pageSize,
  }) async {
    final path = page != null && pageSize != null
        ? '/forms/$formId/analytics?page=$page&pageSize=$pageSize'
        : '/forms/$formId/analytics';
    final json = await AuthService.get(path);
    return FormAnalytics.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// POST /forms/{id}/banner
  static Future<String> uploadBanner(
    int formId,
    Uint8List bytes,
    String filename,
  ) =>
      _uploadFile('/forms/$formId/banner', bytes, filename, 'bannerImage');

  /// POST /forms/{formId}/questions/{id}/upload-image
  static Future<String> uploadQuestionImage(
    int formId,
    int questionId,
    Uint8List bytes,
    String filename,
  ) =>
      _uploadFile(
        '/forms/$formId/questions/$questionId/upload-image',
        bytes,
        filename,
        'questionImage',
      );

  /// POST /forms/{formId}/questions/{id}/upload-audio
  static Future<String> uploadQuestionAudio(
    int formId,
    int questionId,
    Uint8List bytes,
    String filename,
  ) =>
      _uploadFile(
        '/forms/$formId/questions/$questionId/upload-audio',
        bytes,
        filename,
        'questionAudio',
      );

  static Future<String> _uploadFile(
    String path,
    Uint8List bytes,
    String filename,
    String dataKey,
  ) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    var response = await _upload(uri, bytes, filename);
    if (response.statusCode == 401 &&
        response.headers['token-expired'] == 'true' &&
        await AuthService.refreshToken()) {
      response = await _upload(uri, bytes, filename);
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('Respons server tidak valid.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(json['message'] as String? ?? 'Terjadi kesalahan.');
    }
    return (json['data'] as Map<String, dynamic>?)?[dataKey] as String? ?? '';
  }

  static Future<http.Response> _upload(
    Uri uri,
    Uint8List bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer ${AuthService.token}';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final streamed = await request.send().timeout(AuthService.timeout);
    return await http.Response.fromStream(streamed);
  }

  /// GET /forms/{id}/share
  static Future<Map<String, dynamic>> getShareInfo(int formId) async {
    final json = await AuthService.get('/forms/$formId/share');
    return json['data'] as Map<String, dynamic>? ?? {};
  }

  /// GET /forms/{id}/share/qr
  static Future<Uint8List?> getShareQr(int formId) async {
    final bytes = await _authGetBytes('/forms/$formId/share/qr');
    return _isPng(bytes) ? bytes : null;
  }

  static bool _isPng(Uint8List bytes) {
    if (bytes.length < 8) return false;
    const magic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (var i = 0; i < 8; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  static Future<Uint8List> _authGetBytes(String path) async {
    var response = await _getBytes(path);
    if (response.$1 == 401 &&
        response.$2['token-expired'] == 'true' &&
        await AuthService.refreshToken()) {
      response = await _getBytes(path);
    }
    return response.$3;
  }

  static Future<(int, Map<String, String>, Uint8List)> _getBytes(
    String path,
  ) async {
    final request = http.Request('GET', Uri.parse('$apiBaseUrl$path'));
    request.headers['Authorization'] = 'Bearer ${AuthService.token}';
    final streamed = await request.send().timeout(AuthService.timeout);
    final res = await http.Response.fromStream(streamed);
    return (res.statusCode, res.headers, res.bodyBytes);
  }
}
