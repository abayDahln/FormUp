import 'auth_service.dart';

/// Model form ringan hasil `GET /api/forms` & `POST /api/forms`.
class FormData {
  final int id;
  final String title;
  final String? description;
  final String? bannerImage;
  final String formLink;
  final String status;
  final int responseCount;

  const FormData({
    required this.id,
    required this.title,
    required this.formLink,
    required this.status,
    this.description,
    this.bannerImage,
    this.responseCount = 0,
  });

  factory FormData.fromJson(Map<String, dynamic> json) => FormData(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        bannerImage: json['bannerImage'] as String?,
        formLink: json['formLink'] as String? ?? '',
        status: json['status'] as String? ?? 'draft',
        responseCount: json['responseCount'] as int? ?? 0,
      );
}

/// Opsi pertanyaan (hasil GET question).
class QuestionOptionData {
  final int? id;
  final String optionText;
  final bool? isCorrect;

  const QuestionOptionData({this.id, required this.optionText, this.isCorrect});
}

/// Pertanyaan lengkap (hasil `GET /api/forms/{id}/questions`).
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

/// Item riwayat: form yang pernah dikerjakan user (GET /api/users/me/responses).
class MyResponseItem {
  final int responseId;
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

/// Klien untuk endpoint forms & questions.
class FormService {
  /// POST /forms — buat form baru, balikin id form.
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

  /// GET /forms/{id} — detail form (title, description, settings, dsb).
  static Future<Map<String, dynamic>> getForm(int id) async {
    final json = await AuthService.get('/forms/$id');
    return json['data'] as Map<String, dynamic>;
  }

  /// GET /forms — daftar form milik sendiri.
  static Future<List<FormData>> getMyForms() async {
    final json = await AuthService.get('/forms');
    return [
      for (final f in json['data'] as List<dynamic>? ?? [])
        FormData.fromJson(f as Map<String, dynamic>),
    ];
  }

  /// PUT /forms/{id} — update title/description/link form.
  static Future<void> updateForm(
    int id, {
    String? title,
    String? description,
    String? formLink,
  }) async {
    await AuthService.put('/forms/$id', {
      'title': ?title,
      'description': ?description,
      'formLink': ?formLink,
    });
  }

  /// PATCH /forms/{id}/settings — update pengaturan form.
  static Future<void> updateSettings(int id, Map<String, dynamic> settings) =>
      AuthService.patch('/forms/$id/settings', settings);

  /// GET /forms/{id}/questions — daftar pertanyaan form.
  static Future<List<QuestionData>> getQuestions(int formId) async {
    final json = await AuthService.get('/forms/$formId/questions');
    return [
      for (final q in json['data'] as List<dynamic>? ?? [])
        QuestionData.fromJson(q as Map<String, dynamic>),
    ];
  }

  /// POST /forms/{id}/questions — buat pertanyaan baru (untuk form baru).
  static Future<void> saveQuestions(
    int formId,
    List<Map<String, dynamic>> questions,
  ) async {
    await AuthService.post('/forms/$formId/questions', {
      'questions': questions,
    });
  }

  /// PUT /forms/{id}/questions — update in-place (edit form lama).
  static Future<void> updateQuestions(
    int formId,
    List<Map<String, dynamic>> questions,
  ) async {
    await AuthService.put('/forms/$formId/questions', {
      'questions': questions,
    });
  }

  /// POST /forms/{id}/publish — toggle publish/draft.
  static Future<void> publish(int formId) async {
    await AuthService.post('/forms/$formId/publish', {});
  }

  /// DELETE /forms/{id} — hapus form (soft delete).
  static Future<void> deleteForm(int id) => AuthService.delete('/forms/$id');

  /// GET /users/me/responses — riwayat form yang pernah dikerjakan user.
  static Future<List<MyResponseItem>> getMyResponses() async {
    final json = await AuthService.get('/users/me/responses');
    return [
      for (final r in json['data'] as List<dynamic>? ?? [])
        MyResponseItem.fromJson(r as Map<String, dynamic>),
    ];
  }
}
