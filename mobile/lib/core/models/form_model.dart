class QuestionModel {
  String id;
  String questionText;
  String
  type; // 'essay', 'multiple_choice', 'checkbox', 'dropdown', 'date_time', 'upload'
  List<String>? options;
  List<String>? correctAnswer;
  bool isRequired;

  QuestionModel({
    required this.id,
    required this.questionText,
    required this.type,
    this.options,
    this.correctAnswer,
    this.isRequired = true,
  });
}
