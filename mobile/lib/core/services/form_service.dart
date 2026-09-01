import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:form_up/core/cache/api_cache.dart';
import 'package:form_up/core/utils/action_debouncer.dart';
import 'auth_service.dart';
import 'public_form_service.dart' show MyAttempt, PublicFormResult;

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
  final int? points;
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
    this.points,
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
        points: json['points'] as int?,
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
        totalResponses: (json['totalResponses'] ?? json['TotalResponses']) as int? ?? 0,
        totalQuestions: (json['totalQuestions'] ?? json['TotalQuestions']) as int? ?? 0,
        scorableQuestions: (json['scorableQuestions'] ?? json['ScorableQuestions']) as int? ?? 0,
        averageScore: ((json['averageScore'] ?? json['AverageScore']) as num?)?.toDouble(),
        respondents: [
          for (final r in (json['respondents'] ?? json['Respondents']) as List<dynamic>? ?? [])
            RespondentAnalyticsData.fromJson(Map<String, dynamic>.from(r as Map)),
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
    final raw = (json['submittedAt'] ?? json['SubmittedAt']) as String?;
    return RespondentAnalyticsData(
      responseId: (json['responseId'] ?? json['ResponseId'] ?? json['id'] ?? 0) as int,
      respondentName: (json['respondentName'] ?? json['RespondentName']) as String?,
      submittedAt: raw == null ? DateTime.now() : DateTime.tryParse(raw) ?? DateTime.now(),
      answeredCount: (json['answeredCount'] ?? json['AnsweredCount']) as int? ?? 0,
      totalQuestions: (json['totalQuestions'] ?? json['TotalQuestions']) as int? ?? 0,
      correctCount: (json['correctCount'] ?? json['CorrectCount']) as int? ?? 0,
      scorableQuestions: (json['scorableQuestions'] ?? json['ScorableQuestions']) as int? ?? 0,
      score: ((json['score'] ?? json['Score']) as num?)?.toDouble(),
      answers: [
        for (final a in (json['answers'] ?? json['Answers']) as List<dynamic>? ?? [])
          AnswerAnalyticsData.fromJson(Map<String, dynamic>.from(a as Map)),
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

/// Item umpan balik dari responden
class FormFeedbackItem {
  final int id;
  final int formId;
  final String formTitle;
  final int? userId;
  final String userName;
  final String reason;
  final String? description;
  final DateTime createdAt;

  const FormFeedbackItem({
    required this.id,
    required this.formId,
    required this.formTitle,
    required this.userName,
    required this.reason,
    required this.createdAt,
    this.userId,
    this.description,
  });

  factory FormFeedbackItem.fromJson(Map<String, dynamic> json) => FormFeedbackItem(
        id: json['id'] as int,
        formId: json['formId'] as int,
        formTitle: json['formTitle'] as String? ?? '',
        userId: json['userId'] as int?,
        userName: json['userName'] as String? ?? 'Anonim',
        reason: json['reason'] as String? ?? '',
        description: json['description'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Klien forms & questions
class FormService {
  static String get _scope => AuthService.cacheScope;

  static void _invalidateCaches() {
    ApiCache.invalidatePrefix('forms:');
    ApiCache.invalidatePrefix('publicForms:');
    ApiCache.invalidatePrefix('http:get:');
    // Auto-refresh daftar (home + form tab) setelah add/edit/hapus/publish/import/banner
    // formsVersion dipakai sebagai cache-buster di getMyForms/getMyResponses/getQuestions
    formsVersion.value++;
  }

  /// POST /forms
  static Future<int> createForm({
    required String title,
    String? description,
  }) async {
    final json = await AuthService.post('/forms', {
      'title': title,
      'description': description,
    });
    _invalidateCaches();
    final data = json['data'] as Map<String, dynamic>;
    return data['id'] as int;
  }

  /// GET /forms/{id} — v2 bust cache agar formToken yang sebelumnya hilang ikut terambil
  static Future<Map<String, dynamic>> getForm(int id) async {
    return ApiCache.get(
      'forms:detail:v2:$_scope:$id',
      const Duration(seconds: 30),
      () async {
        final json = await AuthService.get('/forms/$id');
        return json['data'] as Map<String, dynamic>;
      },
    );
  }

  /// GET /forms
  static Future<List<FormData>> getMyForms() async {
    return ApiCache.get(
      'forms:list:$_scope:${formsVersion.value}',
      const Duration(seconds: 20),
      () async {
        final json = await AuthService.get('/forms');
        return [
          for (final f in json['data'] as List<dynamic>? ?? [])
            FormData.fromJson(f as Map<String, dynamic>),
        ];
      },
    );
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
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (formLink != null) 'formLink': formLink,
      if (bannerImage != null) 'bannerImage': bannerImage,
    });
    _invalidateCaches();
  }

  /// PATCH /forms/{id}/settings
  static Future<void> updateSettings(int id, Map<String, dynamic> settings) async {
    await AuthService.patch('/forms/$id/settings', settings);
    _invalidateCaches();
  }

  /// GET /forms/{id}/questions
  static Future<List<QuestionData>> getQuestions(int formId) async {
    return ApiCache.get(
      'forms:questions:$_scope:$formId:${formsVersion.value}',
      const Duration(seconds: 60),
      () async {
        final json = await AuthService.get('/forms/$formId/questions');
        return [
          for (final q in json['data'] as List<dynamic>? ?? [])
            QuestionData.fromJson(q as Map<String, dynamic>),
        ];
      },
    );
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
    _invalidateCaches();
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
    _invalidateCaches();
    return [
      for (final q in json['data'] as List<dynamic>? ?? [])
        (q as Map<String, dynamic>),
    ];
  }

  /// DELETE /forms/{id}/questions
  /// Menghapus seluruh soal pada form.
  static Future<void> deleteAllQuestions(int formId) async {
    await AuthService.delete('/forms/$formId/questions');
    _invalidateCaches();
  }

  /// POST /forms/{id}/publish
  static Future<void> publish(int formId) async {
    await AuthService.post('/forms/$formId/publish', {});
    _invalidateCaches();
  }

  /// DELETE /forms/{id}
  static Future<void> deleteForm(int id) async {
    await AuthService.delete('/forms/$id');
    _invalidateCaches();
  }

  /// GET /users/me/responses
  static Future<List<MyResponseItem>> getMyResponses() async {
    return ApiCache.get(
      'forms:myResponses:$_scope:${formsVersion.value}',
      const Duration(seconds: 20),
      () async {
        final json = await AuthService.get('/users/me/responses');
        return [
          for (final r in json['data'] as List<dynamic>? ?? [])
            MyResponseItem.fromJson(r as Map<String, dynamic>),
        ];
      },
    );
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
    return ApiCache.get(
      'forms:responses:$_scope:$formId:$path',
      const Duration(seconds: 15),
      () async {
        final json = await AuthService.get(path);
        final data = json['data'];

        // Backward-compat: tanpa param server mengembalikan array polos.
        if (data is List) {
          return PagedResult(
            items: [
              for (final r in data)
                ResponseListItemData.fromJson(r as Map<String, dynamic>),
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
      },
    );
  }

  /// GET /forms/{id}/responses/{responseId}
  static Future<ResponseDetailData> getResponseDetail(
    int formId,
    int responseId,
  ) async {
    return ApiCache.get(
      'forms:responseDetail:$_scope:$formId:$responseId',
      const Duration(seconds: 30),
      () async {
        final json = await AuthService.get('/forms/$formId/responses/$responseId');
        return ResponseDetailData.fromJson(
          json['data'] as Map<String, dynamic>,
        );
      },
    );
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

  /// GET /forms/{formId}/feedbacks
  static Future<List<FormFeedbackItem>> getFormFeedbacks(int formId) async {
    final json = await AuthService.get('/forms/$formId/feedbacks');
    final list = json['data'] as List<dynamic>? ?? [];
    return list.map((item) => FormFeedbackItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// GET /forms/{id}/analytics
  static Future<FormAnalytics> getAnalytics(
    int formId, {
    int? page,
    int? pageSize,
    String? search,
  }) async {
    final params = <String>[
      if (page != null && pageSize != null) 'page=$page',
      if (page != null && pageSize != null) 'pageSize=$pageSize',
      if (search != null && search.trim().isNotEmpty)
        'search=${Uri.encodeQueryComponent(search.trim())}',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    // analytics agregasi berat -> timeout lebih panjang, bypass cache ganda (pakai timeout khusus)
    return ApiCache.get(
      'forms:analytics:$_scope:$formId:$query',
      const Duration(seconds: 20),
      () async {
        final json = await AuthService.get('/forms/$formId/analytics$query', timeout: const Duration(seconds: 20));
        final data = json['data'];
        if (data is Map<String, dynamic>) {
          return FormAnalytics.fromJson(data);
        }
        // fallback defensif bila server kirim format paged/list kosong
        if (data == null) return const FormAnalytics();
        return FormAnalytics.fromJson(Map<String, dynamic>.from(data as Map));
      },
    );
  }

  /// GET /forms/{formId}/responses/{responseId}/result
  /// Hasil lengkap satu respon (skor + kunci jawaban) untuk pemilik form.
  static Future<PublicFormResult> getResponseResult(
    int formId,
    int responseId,
  ) async {
    return ApiCache.get(
      'forms:responseResult:$_scope:$formId:$responseId',
      const Duration(seconds: 30),
      () async {
        final json = await AuthService.get(
          '/forms/$formId/responses/$responseId/result',
        );
        return PublicFormResult.fromJson(
          json['data'] as Map<String, dynamic>,
        );
      },
    );
  }

  /// GET /forms/{formId}/responses/{responseId}/attempts
  /// Semua attempt responden yang sama pada form yang sama.
  static Future<List<MyAttempt>> getRespondentAttempts(
    int formId,
    int responseId,
  ) async {
    return ApiCache.get(
      'forms:attempts:$_scope:$formId:$responseId',
      const Duration(seconds: 30),
      () async {
        final json = await AuthService.get(
          '/forms/$formId/responses/$responseId/attempts',
        );
        return [
          for (final a in json['data'] as List<dynamic>? ?? [])
            MyAttempt.fromJson(a as Map<String, dynamic>),
        ];
      },
    );
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
    if (!AppDebouncer.tryAcquire('upload:$path')) {
      throw const ApiException('Terlalu cepat, tunggu sebentar.');
    }
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
      throw const ApiException('Terjadi kesalahan, coba lagi nanti.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(json['message'] as String? ?? 'Terjadi kesalahan.');
    }
    _invalidateCaches();
    return (json['data'] as Map<String, dynamic>?)?[dataKey] as String? ?? '';
  }

  static const _uploadTimeout = Duration(seconds: 60);

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
    try {
      final streamed = await request.send().timeout(_uploadTimeout);
      return await http.Response.fromStream(streamed).timeout(_uploadTimeout);
    } on TimeoutException {
      throw const ApiException('Upload timeout. File besar atau koneksi lambat, coba lagi.');
    }
  }

  /// POST /forms/{id}/questions/import/preview — parse & validasi file impor
  /// (.docx/.pdf/.xlsx/.csv) TANPA menyimpan ke database.
  /// Return `{preview, blocked, totalRows, totalQuestions, skippedCount,
  /// canImport, errors: [{rowNumber, field, message}], questions: [...]}`.
  static Future<Map<String, dynamic>> previewQuestionImport(
    int formId,
    Uint8List bytes,
    String filename,
  ) =>
      _postQuestionImport(
        '/forms/$formId/questions/import/preview',
        bytes,
        filename,
      );

  /// POST /forms/{id}/questions/import — simpan hasil impor soal ke database.
  /// Panggil setelah user konfirmasi dari preview.
  /// Return `{totalImported, totalSkipped, errors}`.
  static Future<Map<String, dynamic>> saveQuestionImport(
    int formId,
    Uint8List bytes,
    String filename,
  ) =>
      _postQuestionImport('/forms/$formId/questions/import', bytes, filename);

  static Future<Map<String, dynamic>> _postQuestionImport(
    String path,
    Uint8List bytes,
    String filename,
  ) async {
    if (!AppDebouncer.tryAcquire('import:$path')) {
      throw const ApiException('Terlalu cepat, tunggu sebentar.');
    }
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
      throw const ApiException('Terjadi kesalahan, coba lagi nanti.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(json['message'] as String? ?? 'Terjadi kesalahan.');
    }
    _invalidateCaches();
    return json['data'] as Map<String, dynamic>? ?? {};
  }

  /// GET /templates/import-questions?format=csv|xlsx|docx|pdf
  /// Download template impor soal — tidak perlu auth, di-rate-limit server 10/menit.
  /// Dipakai mobile agar paritas dengan web `templateDownloadUrl` di `apiService.js:335`.
  static Future<Uint8List> downloadImportTemplate(String format) async {
    final f = format.toLowerCase();
    if (!{'csv', 'xlsx', 'docx', 'pdf'}.contains(f)) {
      throw const ApiException('Format tidak didukung. Gunakan csv, xlsx, docx, atau pdf.');
    }
    final uri = Uri.parse('$apiBaseUrl/templates/import-questions?format=$f');
    final res = await http.get(uri).timeout(AuthService.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Gagal mengunduh template';
      try {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        msg = j['message'] as String? ?? msg;
      } catch (_) {}
      throw ApiException(msg);
    }
    return res.bodyBytes;
  }

  /// GET /forms/{id}/share
  static Future<Map<String, dynamic>> getShareInfo(int formId) async {
    final json = await AuthService.get('/forms/$formId/share');
    return json['data'] as Map<String, dynamic>? ?? {};
  }

  /// GET /forms/{formId}/responses/export — CSV (owner only)
  /// Endpoint API: ResponsesController.cs:259 `GET /api/forms/{formId}/responses/export`
  /// Mengembalikan file CSV dengan BOM UTF-8, header "Response ID,Submitted At,Respondent,...".
  static Future<Uint8List> exportResponses(int formId) async {
    final bytes = await _authGetBytes('/forms/$formId/responses/export');
    if (bytes.isEmpty) throw const ApiException('Gagal mengekspor data respons.');
    // Validasi sederhana: endpoint sukses mengembalikan text/csv, error JSON diawali {
    if (bytes.length > 1 && bytes[0] == 0x7B) {
      try {
        final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        throw ApiException(j['message'] as String? ?? 'Gagal mengekspor data respons.');
      } catch (_) {}
    }
    return bytes;
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
