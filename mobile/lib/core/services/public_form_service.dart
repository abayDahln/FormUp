import 'auth_service.dart';

/// Info form publik
class PublicFormInfo {
  final int id;
  final String title;
  final String? description;
  final String? bannerImage;
  final bool requiresToken;
  final bool requiresLogin;
  final bool oneResponse;
  final bool isOwner;
  final int questionCount;
  final int? formTypeId;
  final bool? showScore;
  final int? timerDuration;
  final bool? randomizeQuestions;
  final DateTime? openFormTime;
  final DateTime? closeFormTime;

  const PublicFormInfo({
    required this.id,
    required this.title,
    this.description,
    this.bannerImage,
    this.requiresToken = false,
    this.requiresLogin = false,
    this.oneResponse = false,
    this.isOwner = false,
    this.questionCount = 0,
    this.formTypeId = 1,
    this.showScore,
    this.timerDuration,
    this.randomizeQuestions,
    this.openFormTime,
    this.closeFormTime,
  });

  factory PublicFormInfo.fromJson(Map<String, dynamic> json) =>
      PublicFormInfo(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        bannerImage: json['bannerImage'] as String?,
        requiresToken: json['requiresToken'] as bool? ?? false,
        requiresLogin: json['requiresLogin'] as bool? ?? false,
        oneResponse: json['oneResponse'] as bool? ?? false,
        isOwner: json['isOwner'] as bool? ?? false,
        questionCount: json['questionCount'] as int? ?? 0,
        formTypeId: json['formTypeId'] as int? ?? 1,
        showScore: json['showScore'] as bool?,
        timerDuration: json['timerDuration'] as int?,
        randomizeQuestions: json['randomizeQuestions'] as bool?,
        openFormTime: _parseDate(json['openFormTime']),
        closeFormTime: _parseDate(json['closeFormTime']),
      );
}

DateTime? _parseDate(Object? value) {
  final s = value as String?;
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s);
}

class PublicOption {
  final int id;
  final String optionText;
  final String? optionImage;

  const PublicOption({
    required this.id,
    required this.optionText,
    this.optionImage,
  });
}

class PublicQuestion {
  final int id;
  final int typeId;
  final String question;
  final int questionOrder;
  final bool? isRequired;
  final bool? randomizeOptions;
  final String? questionImage;
  final String? questionAudio;
  final List<PublicOption> options;

  const PublicQuestion({
    required this.id,
    required this.typeId,
    required this.question,
    required this.questionOrder,
    this.isRequired,
    this.randomizeOptions,
    this.questionImage,
    this.questionAudio,
    this.options = const [],
  });

  factory PublicQuestion.fromJson(Map<String, dynamic> json) =>
      PublicQuestion(
        id: json['id'] as int,
        typeId: json['typeId'] as int,
        question: json['question'] as String? ?? '',
        questionOrder: json['questionOrder'] as int? ?? 0,
        isRequired: json['isRequired'] as bool?,
        randomizeOptions: json['randomizeOptions'] as bool?,
        questionImage: json['questionImage'] as String?,
        questionAudio: json['questionAudio'] as String?,
        options: [
          for (final o in json['options'] as List<dynamic>? ?? [])
            PublicOption(
              id: o['id'] as int,
              optionText: o['optionText'] as String? ?? '',
              optionImage: o['optionImage'] as String?,
            ),
        ],
      );
}

class PublicResultAnswer {
  final int questionId;
  final String question;
  final int typeId;
  final String? answerText;
  final String? correctAnswer;
  final bool? isCorrect;
  final List<String> options;
  final List<String> selectedOptions;

  const PublicResultAnswer({
    required this.questionId,
    required this.question,
    required this.typeId,
    this.answerText,
    this.correctAnswer,
    this.isCorrect,
    this.options = const [],
    this.selectedOptions = const [],
  });

  factory PublicResultAnswer.fromJson(Map<String, dynamic> json) =>
      PublicResultAnswer(
        questionId: json['questionId'] as int,
        question: json['question'] as String? ?? '',
        typeId: json['typeId'] as int,
        answerText: json['answerText'] as String?,
        correctAnswer: json['correctAnswer'] as String?,
        isCorrect: json['isCorrect'] as bool?,
        options: [
          for (final o in json['options'] as List<dynamic>? ?? [])
            o as String? ?? '',
        ],
        selectedOptions: [
          for (final o in json['selectedOptions'] as List<dynamic>? ?? [])
            o as String? ?? '',
        ],
      );
}

class PublicFormResult {
  final int responseId;
  final int formId;
  final String formTitle;
  final bool showScore;
  final double? score;
  final int correctCount;
  final int wrongCount;
  final int totalQuestions;
  final int scorableQuestions;
  final int answeredCount;
  final List<PublicResultAnswer> answers;

  const PublicFormResult({
    required this.responseId,
    required this.formId,
    required this.formTitle,
    required this.showScore,
    this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.totalQuestions,
    required this.scorableQuestions,
    required this.answeredCount,
    this.answers = const [],
  });

  factory PublicFormResult.fromJson(Map<String, dynamic> json) =>
      PublicFormResult(
        responseId: json['responseId'] as int,
        formId: json['formId'] as int,
        formTitle: json['formTitle'] as String? ?? '',
        showScore: json['showScore'] as bool? ?? false,
        score: (json['score'] as num?)?.toDouble(),
        correctCount: json['correctCount'] as int? ?? 0,
        wrongCount: json['wrongCount'] as int? ?? 0,
        totalQuestions: json['totalQuestions'] as int? ?? 0,
        scorableQuestions: json['scorableQuestions'] as int? ?? 0,
        answeredCount: json['answeredCount'] as int? ?? 0,
        answers: [
          for (final a in json['answers'] as List<dynamic>? ?? [])
            PublicResultAnswer.fromJson(a as Map<String, dynamic>),
        ],
      );
}

/// Satu attempt pengerjaan user pada sebuah form
class MyAttempt {
  final int responseId;
  final DateTime? submittedAt;
  final bool showScore;
  final double? score;
  final int correctCount;
  final int wrongCount;

  const MyAttempt({
    required this.responseId,
    this.submittedAt,
    this.showScore = false,
    this.score,
    this.correctCount = 0,
    this.wrongCount = 0,
  });

  factory MyAttempt.fromJson(Map<String, dynamic> json) => MyAttempt(
        responseId: json['responseId'] as int,
        submittedAt: _parseDate(json['submittedAt']),
        showScore: json['showScore'] as bool? ?? false,
        score: (json['score'] as num?)?.toDouble(),
        correctCount: json['correctCount'] as int? ?? 0,
        wrongCount: json['wrongCount'] as int? ?? 0,
      );
}

class PublicFormService {
  /// GET /public/forms/{formLink}
  static Future<PublicFormInfo> getFormInfo(String formLink) async {
    final json = await AuthService.get('/public/forms/$formLink');
    return PublicFormInfo.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// POST /public/forms/{formLink}/questions
  static Future<List<PublicQuestion>> getQuestions(
    String formLink, {
    String? token,
  }) async {
    final json = await AuthService.post('/public/forms/$formLink/questions', {
      if (token != null && token.isNotEmpty) 'token': token,
    });
    final data = json['data'] as Map<String, dynamic>;
    return [
      for (final q in data['questions'] as List<dynamic>? ?? [])
        PublicQuestion.fromJson(q as Map<String, dynamic>),
    ];
  }

  /// POST /public/forms/{formLink}/responses
  static Future<Map<String, dynamic>> submit(
    String formLink, {
    String? token,
    String? respondentName,
    required List<Map<String, dynamic>> answers,
  }) async {
    final json = await AuthService.post('/public/forms/$formLink/responses', {
      if (token != null && token.isNotEmpty) 'token': token,
      if (respondentName != null && respondentName.trim().isNotEmpty)
        'respondentName': respondentName.trim(),
      'answers': answers,
    });
    return json['data'] as Map<String, dynamic>;
  }

  /// GET .../responses/{id}
  static Future<PublicFormResult> getResult(
    String formLink,
    int responseId,
  ) async {
    final json =
        await AuthService.get('/public/forms/$formLink/responses/$responseId');
    return PublicFormResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// GET .../my-responses — semua attempt user pada satu form
  static Future<List<MyAttempt>> getMyAttempts(String formLink) async {
    final json = await AuthService.get('/public/forms/$formLink/my-responses');
    return [
      for (final a in json['data'] as List<dynamic>? ?? [])
        MyAttempt.fromJson(a as Map<String, dynamic>),
    ];
  }
}
