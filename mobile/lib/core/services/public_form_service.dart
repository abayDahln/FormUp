import 'package:form_up/core/cache/api_cache.dart';
import 'package:form_up/core/utils/action_debouncer.dart';
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
  // FEAT-6: exam mode
  final bool? isExamMode;
  final bool? disableCopyPaste;
  final bool? detectTabSwitch;
  final bool? autoSubmitOnTabSwitch;
  final int? maxTabSwitch;
  // FEAT-9: theme
  final String? themePrimaryColor;
  final String? themeBackgroundColor;
  final String? themeConfig;

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
    this.isExamMode,
    this.disableCopyPaste,
    this.detectTabSwitch,
    this.autoSubmitOnTabSwitch,
    this.maxTabSwitch,
    this.themePrimaryColor,
    this.themeBackgroundColor,
    this.themeConfig,
  });

  factory PublicFormInfo.fromJson(Map<String, dynamic> json) => PublicFormInfo(
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
    isExamMode: json['isExamMode'] as bool?,
    disableCopyPaste: json['disableCopyPaste'] as bool?,
    detectTabSwitch: json['detectTabSwitch'] as bool?,
    autoSubmitOnTabSwitch: json['autoSubmitOnTabSwitch'] as bool?,
    maxTabSwitch: json['maxTabSwitch'] as int?,
    themePrimaryColor: json['themePrimaryColor'] as String?,
    themeBackgroundColor: json['themeBackgroundColor'] as String?,
    themeConfig: json['themeConfig'] as String?,
  );
}

DateTime? _parseDate(Object? value) {
  final s = value as String?;
  if (s == null || s.isEmpty) return null;

  final dt = DateTime.tryParse(s);
  if (dt == null) return null;

  return dt.toLocal();
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

  factory PublicQuestion.fromJson(Map<String, dynamic> json) => PublicQuestion(
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
  final int answerId;
  final String question;
  final int typeId;
  final String? answerText;
  final String? correctAnswer;
  final bool? isCorrect;
  final double? manualScore;
  final bool? isCorrectOverride;
  final String? overrideNote;
  final double? earnedPoints;
  final List<String> options;
  final List<String> selectedOptions;

  const PublicResultAnswer({
    required this.questionId,
    this.answerId = 0,
    required this.question,
    required this.typeId,
    this.answerText,
    this.correctAnswer,
    this.isCorrect,
    this.manualScore,
    this.isCorrectOverride,
    this.overrideNote,
    this.earnedPoints,
    this.options = const [],
    this.selectedOptions = const [],
  });

  factory PublicResultAnswer.fromJson(Map<String, dynamic> json) =>
      PublicResultAnswer(
        questionId: json['questionId'] as int,
        question: json['question'] as String? ?? '',
        answerId: json['answerId'] as int? ?? json['id'] as int? ?? 0,
        typeId: json['typeId'] as int,
        answerText: json['answerText'] as String?,
        correctAnswer: json['correctAnswer'] as String?,
        isCorrect: json['isCorrect'] as bool?,
        manualScore: (json['manualScore'] as num?)?.toDouble(),
        isCorrectOverride: json['isCorrectOverride'] as bool?,
        overrideNote: json['overrideNote'] as String?,
        earnedPoints: (json['earnedPoints'] as num?)?.toDouble(),
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

/// Hasil POST exam-events: sessionId + hitungan server + flag auto-submit.
class ExamEventResult {
  final String sessionId;
  final int violationCount;
  final int tabSwitchCount;
  final bool shouldAutoSubmit;

  const ExamEventResult({
    required this.sessionId,
    this.violationCount = 0,
    this.tabSwitchCount = 0,
    this.shouldAutoSubmit = false,
  });

  factory ExamEventResult.fromJson(Map<String, dynamic> json) =>
      ExamEventResult(
        sessionId: json['sessionId'] as String? ?? '',
        violationCount: json['violationCount'] as int? ?? 0,
        tabSwitchCount: json['tabSwitchCount'] as int? ?? 0,
        shouldAutoSubmit: json['shouldAutoSubmit'] as bool? ?? false,
      );
}

class PublicFormService {
  static String get _scope => AuthService.cacheScope;

  /// GET /public/forms/{formLink}
  static Future<PublicFormInfo> getFormInfo(String formLink) async {
    return ApiCache.get(
      'publicForms:info:$_scope:$formLink',
      const Duration(seconds: 45),
      () async {
        final json = await AuthService.get('/public/forms/$formLink');
        return PublicFormInfo.fromJson(json['data'] as Map<String, dynamic>);
      },
    );
  }

  /// POST /public/forms/{formLink}/questions
  static Future<List<PublicQuestion>> getQuestions(
    String formLink, {
    String? token,
  }) async {
    final cacheKey = 'publicForms:questions:$_scope:$formLink:${token ?? ''}';
    return ApiCache.get(cacheKey, const Duration(seconds: 120), () async {
      final json = await AuthService.post('/public/forms/$formLink/questions', {
        if (token != null && token.isNotEmpty) 'token': token,
      });
      final data = json['data'] as Map<String, dynamic>;
      return [
        for (final q in data['questions'] as List<dynamic>? ?? [])
          PublicQuestion.fromJson(q as Map<String, dynamic>),
      ];
    });
  }

  /// POST /public/forms/{formLink}/responses — debounce 300ms anti spam submit
  static Future<Map<String, dynamic>> submit(
    String formLink, {
    String? token,
    String? respondentName,
    required List<Map<String, dynamic>> answers,
    bool isAutoSubmit = false,
    String? examSessionId,
    int? tabSwitchCount,
    List<Map<String, dynamic>>? violations,
  }) async {
    if (!AppDebouncer.tryAcquire('public:submit:$formLink')) {
      throw const ApiException('Terlalu cepat, tunggu sebentar.');
    }
    final json = await AuthService.post('/public/forms/$formLink/responses', {
      if (token != null && token.isNotEmpty) 'token': token,
      if (respondentName != null && respondentName.trim().isNotEmpty)
        'respondentName': respondentName.trim(),
      'answers': answers,
      if (isAutoSubmit) 'isAutoSubmit': true,
      if (examSessionId != null && examSessionId.isNotEmpty)
        'examSessionId': examSessionId,
      if (tabSwitchCount != null) 'tabSwitchCount': tabSwitchCount,
      if (violations != null && violations.isNotEmpty) 'violations': violations,
    });
    ApiCache.invalidatePrefix('publicForms:');
    ApiCache.invalidatePrefix('http:get:');
    return json['data'] as Map<String, dynamic>;
  }

  /// POST /public/forms/{formLink}/exam-events — mode ujian.
  /// Kirim tepat 1 event per 1 siklus keluar-masuk (hanya saat pergi/paused),
  /// jangan kirim saat kembali agar tidak double-count di server.
  /// sessionId kosong pada event pertama → server generate & kembalikan.
  static Future<ExamEventResult> sendExamEvent(
    String formLink, {
    String? sessionId,
    String? respondentName,
    required String type,
    DateTime? occurredAt,
  }) async {
    final json = await AuthService.post('/public/forms/$formLink/exam-events', {
      if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
      if (respondentName != null && respondentName.trim().isNotEmpty)
        'respondentName': respondentName.trim(),
      'type': type,
      if (occurredAt != null) 'occurredAt': occurredAt.toUtc().toIso8601String(),
    });
    return ExamEventResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// GET .../responses/{id}
  static Future<PublicFormResult> getResult(
    String formLink,
    int responseId,
  ) async {
    return ApiCache.get(
      'publicForms:result:$_scope:$formLink:$responseId',
      const Duration(seconds: 30),
      () async {
        final json = await AuthService.get(
          '/public/forms/$formLink/responses/$responseId',
        );
        return PublicFormResult.fromJson(json['data'] as Map<String, dynamic>);
      },
    );
  }

  /// GET .../my-responses — semua attempt user pada satu form
  /// Diurutkan terlama -> terbaru agar Percobaan #1 = paling lama
  static Future<List<MyAttempt>> getMyAttempts(String formLink) async {
    return ApiCache.get(
      'publicForms:attempts:$_scope:$formLink',
      const Duration(seconds: 20),
      () async {
        final json = await AuthService.get(
          '/public/forms/$formLink/my-responses',
        );
        final list = [
          for (final a in json['data'] as List<dynamic>? ?? [])
            MyAttempt.fromJson(a as Map<String, dynamic>),
        ];
        list.sort((a, b) {
          final da = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return da.compareTo(db);
        });
        return list;
      },
    );
  }
}
