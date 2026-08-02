import 'auth_service.dart';

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

  /// POST /forms/{id}/questions — simpan semua pertanyaan sekaligus.
  /// [questions]: list map `{typeId, question, isRequired, options:[{optionText, isCorrect}]}`.
  static Future<void> saveQuestions(
    int formId,
    List<Map<String, dynamic>> questions,
  ) async {
    await AuthService.post('/forms/$formId/questions', {
      'questions': questions,
    });
  }

  /// POST /forms/{id}/publish — toggle publish/draft.
  static Future<void> publish(int formId) async {
    await AuthService.post('/forms/$formId/publish', {});
  }
}
