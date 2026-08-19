import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'rich_editor.dart';

class OptionDraft {
  int? id;
  final QuillController text;
  bool isCorrect;

  OptionDraft({this.id, String text = '', this.isCorrect = false})
      : text = richTextController(text);

  bool sameAs(OptionDraft other) =>
      isCorrect == other.isCorrect &&
      jsonEncode(text.document.toDelta().toJson()) ==
          jsonEncode(other.text.document.toDelta().toJson());
}

class QuestionDraft {
  int? id;
  int typeId;
  final QuillController question;
  final TextEditingController correctAnswer;
  bool isRequired;
  bool randomizeOptions;
  final List<OptionDraft> options;
  String? questionImage;
  String? questionAudio;

  /// Media baru yang belum ter-upload (draf) — di-upload setelah soal dapat id.
  Uint8List? pendingImageBytes;
  String? pendingImageName;
  Uint8List? pendingAudioBytes;
  String? pendingAudioName;

  QuestionDraft(
    this.typeId, {
    this.id,
    String question = '',
    String correctAnswer = '',
    this.isRequired = true,
    this.randomizeOptions = false,
    this.questionImage,
    this.questionAudio,
  })  : question = richTextController(question),
        correctAnswer = TextEditingController(text: correctAnswer),
        options = [];

  bool get hasOptions => typeId == 2 || typeId == 3;

  /// true bila isi (termasuk opsi) sama — dipakai deteksi perubahan draf.
  bool sameAs(QuestionDraft other) {
    if (typeId != other.typeId) return false;
    if (jsonEncode(question.document.toDelta().toJson()) !=
        jsonEncode(other.question.document.toDelta().toJson())) {
      return false;
    }
    if (correctAnswer.text != other.correctAnswer.text) return false;
    if (isRequired != other.isRequired) return false;
    if (randomizeOptions != other.randomizeOptions) return false;
    if (questionImage != other.questionImage) return false;
    if (questionAudio != other.questionAudio) return false;
    if (!listEquals(pendingImageBytes, other.pendingImageBytes)) return false;
    if (pendingImageName != other.pendingImageName) return false;
    if (!listEquals(pendingAudioBytes, other.pendingAudioBytes)) return false;
    if (pendingAudioName != other.pendingAudioName) return false;
    if (options.length != other.options.length) return false;
    for (var i = 0; i < options.length; i++) {
      if (!options[i].sameAs(other.options[i])) return false;
    }
    return true;
  }

  /// Salinan dalam (controller baru) — dipakai editor soal agar perubahan
  /// tidak langsung menimpa draf di daftar sebelum "Simpan".
  QuestionDraft copy() {
    final copy = QuestionDraft(
      typeId,
      id: id,
      correctAnswer: correctAnswer.text,
      isRequired: isRequired,
      randomizeOptions: randomizeOptions,
      questionImage: questionImage,
      questionAudio: questionAudio,
    );
    copy.question.document =
        Document.fromJson(question.document.toDelta().toJson());
    copy.pendingImageBytes = pendingImageBytes;
    copy.pendingImageName = pendingImageName;
    copy.pendingAudioBytes = pendingAudioBytes;
    copy.pendingAudioName = pendingAudioName;
    for (final o in options) {
      final oc = OptionDraft(id: o.id, isCorrect: o.isCorrect);
      oc.text.document = Document.fromJson(o.text.document.toDelta().toJson());
      copy.options.add(oc);
    }
    return copy;
  }

  /// Tulis ulang isi [other] ke draf ini (dipakai saat "Simpan Soal").
  void copyFrom(QuestionDraft other) {
    typeId = other.typeId;
    question.document =
        Document.fromJson(other.question.document.toDelta().toJson());
    correctAnswer.text = other.correctAnswer.text;
    isRequired = other.isRequired;
    randomizeOptions = other.randomizeOptions;
    questionImage = other.questionImage;
    questionAudio = other.questionAudio;
    pendingImageBytes = other.pendingImageBytes;
    pendingImageName = other.pendingImageName;
    pendingAudioBytes = other.pendingAudioBytes;
    pendingAudioName = other.pendingAudioName;
    for (final o in options) {
      o.text.dispose();
    }
    options
      ..clear()
      ..addAll([
        for (final o in other.options)
          OptionDraft(
            id: o.id,
            text: encodeRichText(o.text),
            isCorrect: o.isCorrect,
          ),
      ]);
  }

  void dispose() {
    question.dispose();
    correctAnswer.dispose();
    for (final o in options) {
      o.text.dispose();
    }
  }
}

const questionTypes = {
  1: ('Essay', Icons.short_text),
  2: ('Pilihan Ganda', Icons.radio_button_checked),
  3: ('Checkbox', Icons.check_box_outlined),
  4: ('Tanggal & Waktu', Icons.calendar_today_outlined),
  5: ('Benar/Salah', Icons.check_circle_outline),
};
