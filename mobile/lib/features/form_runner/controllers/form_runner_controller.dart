import 'package:flutter/material.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/public_form_service.dart';
import 'package:form_up/features/form_runner/controllers/runner_answer_store.dart';

/// Controller state untuk FormRunnerView: menyimpan data form aktif,
/// jawaban responden, dan alur panggilan API publik (info → soal → kirim).
class FormRunnerController {
  final RunnerAnswerStore store = RunnerAnswerStore();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController tokenController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  int formTypeId = 1;
  int currentQuestion = 0;
  String? formLink;
  PublicFormInfo? info;
  List<PublicQuestion> questions = [];
  PublicFormResult? result;

  bool get requiresToken => info?.requiresToken ?? false;
  bool get isLoggedIn => AuthService.token != null;

  void dispose() {
    store.dispose();
    codeController.dispose();
    tokenController.dispose();
    nameController.dispose();
  }

  /// Ambil info form berdasarkan kode.
  /// Mengembalikan null bila user adalah pemilik form (tidak boleh mengisi).
  Future<PublicFormInfo?> fetchInfo(String code) async {
    final fetched = await PublicFormService.getFormInfo(code);
    if (fetched.isOwner) {
      formLink = null;
      info = null;
      return null;
    }
    formLink = code;
    info = fetched;
    return fetched;
  }

  Future<List<PublicQuestion>> fetchQuestions(String token) async {
    final questions = await PublicFormService.getQuestions(
      formLink!,
      token: token.trim().isEmpty ? null : token.trim(),
    );
    store.init(questions);
    this.questions = questions;
    formTypeId = info?.formTypeId ?? 1;
    currentQuestion = 0;
    return questions;
  }

  /// Kirim jawaban; mengembalikan id respons.
  Future<int> submitAnswers(List<Map<String, dynamic>> answers, {bool isAutoSubmit = false}) async {
    final data = await PublicFormService.submit(
      formLink!,
      token: tokenController.text.trim().isEmpty
          ? null
          : tokenController.text.trim(),
      respondentName: isLoggedIn ? null : nameController.text,
      answers: answers,
      isAutoSubmit: isAutoSubmit,
    );
    return data['responseId'] as int;
  }

  Future<PublicFormResult> fetchResult(int responseId) {
    return PublicFormService.getResult(formLink!, responseId);
  }

  /// Bersihkan state untuk kembali ke step kode (form lain).
  void clearForRestart() {
    info = null;
    questions = [];
    result = null;
    formLink = null;
    currentQuestion = 0;
    tokenController.clear();
    nameController.clear();
  }

  /// Siapkan pengerjaan ulang: jawaban dikosongkan, hasil dihapus.
  void retryInit() {
    result = null;
    currentQuestion = 0;
    store.reinit(questions);
  }
}
