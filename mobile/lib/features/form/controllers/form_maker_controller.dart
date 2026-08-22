import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/rich_editor.dart';

/// Snapshot nilai form untuk deteksi perubahan (dipakai konfirmasi keluar).
class FormMakerSnapshot {
  final String title;
  final String desc;
  final int formTypeId;
  final bool showScore;
  final bool randomizeQuestions;
  final bool oneResponse;
  final bool requiredLogin;
  final DateTime? openFormTime;
  final DateTime? closeFormTime;
  final String timer;
  final String token;
  final String customLink;
  final String? bannerImage;

  const FormMakerSnapshot({
    required this.title,
    required this.desc,
    required this.formTypeId,
    required this.showScore,
    required this.randomizeQuestions,
    required this.oneResponse,
    required this.requiredLogin,
    required this.openFormTime,
    required this.closeFormTime,
    required this.timer,
    required this.token,
    required this.customLink,
    required this.bannerImage,
  });
}

/// Controller state untuk FormMakerScreen: menampung seluruh nilai form,
/// snapshot/deteksi perubahan, parsing data form, dan payload pengaturan.
class FormMakerController {
  final QuillController titleController = richTextController(null);
  final QuillController descController = richTextController(null);
  final TextEditingController timerController = TextEditingController();
  String timerUnit = 'menit';
  final TextEditingController tokenController = TextEditingController();
  final TextEditingController customLinkController = TextEditingController();

  int formTypeId = 1;
  bool showScore = false;
  bool randomizeQuestions = false;
  bool oneResponse = false;
  bool requiredLogin = false;
  DateTime? openFormTime;
  DateTime? closeFormTime;

  String? bannerImage;
  Uint8List? newBanner;
  bool bannerCleared = false;

  bool openTimeAlreadySet = false;

  FormMakerSnapshot? baseline;

  void dispose() {
    titleController.dispose();
    descController.dispose();
    timerController.dispose();
    tokenController.dispose();
    customLinkController.dispose();
  }

  String _delta(QuillController c) =>
      jsonEncode(c.document.toDelta().toJson());

  FormMakerSnapshot snapshot() => FormMakerSnapshot(
        title: _delta(titleController),
        desc: _delta(descController),
        formTypeId: formTypeId,
        showScore: showScore,
        randomizeQuestions: randomizeQuestions,
        oneResponse: oneResponse,
        requiredLogin: requiredLogin,
        openFormTime: openFormTime,
        closeFormTime: closeFormTime,
        timer: '$timerUnit:${timerController.text}',
        token: tokenController.text,
        customLink: customLinkController.text,
        bannerImage: newBanner != null
            ? 'new:${newBanner.hashCode}'
            : bannerCleared
                ? ''
                : bannerImage,
      );

  bool get hasChanges {
    final base = baseline;
    if (base == null) return false;
    final cur = snapshot();
    return base.title != cur.title ||
        base.desc != cur.desc ||
        base.formTypeId != cur.formTypeId ||
        base.showScore != cur.showScore ||
        base.randomizeQuestions != cur.randomizeQuestions ||
        base.oneResponse != cur.oneResponse ||
        base.requiredLogin != cur.requiredLogin ||
        base.openFormTime != cur.openFormTime ||
        base.closeFormTime != cur.closeFormTime ||
        base.timer != cur.timer ||
        base.token != cur.token ||
        base.customLink != cur.customLink ||
        base.bannerImage != cur.bannerImage;
  }

  /// Isi seluruh field dari respons API getForm.
  void applyForm(Map<String, dynamic> form) {
    final settings = form['settings'] as Map<String, dynamic>?;
    final rawOpen = settings?['openFormTime'] as String?;
    final rawClose = settings?['closeFormTime'] as String?;
    titleController.document = richDocument(form['title'] as String?);
    descController.document = richDocument(form['description'] as String?);
    bannerImage = form['bannerImage'] as String?;
    newBanner = null;
    bannerCleared = false;
    formTypeId = (settings?['formTypeId'] as int?) ?? 1;
    showScore = settings?['showScore'] == true;
    randomizeQuestions = settings?['randomizeQuestions'] == true;
    oneResponse = settings?['oneResponse'] == true;
    requiredLogin = settings?['requiredLogin'] == true;
    openFormTime =
        rawOpen != null ? DateTime.tryParse(rawOpen)?.toLocal() : null;
    closeFormTime =
        rawClose != null ? DateTime.tryParse(rawClose)?.toLocal() : null;
    openTimeAlreadySet = openFormTime != null;
    if (settings?['timerDuration'] is int) {
      final timerSeconds = settings!['timerDuration'] as int;
      if (timerSeconds > 0 && timerSeconds % 3600 == 0) {
        timerUnit = 'jam';
        timerController.text = '${timerSeconds ~/ 3600}';
      } else if (timerSeconds > 0) {
        timerUnit = 'menit';
        timerController.text = '${timerSeconds ~/ 60}';
      } else {
        timerController.text = '';
      }
    }
    customLinkController.text = form['formLink'] as String? ?? '';
    baseline = snapshot();
  }

  /// Bangun payload settings untuk updateSettings.
  Map<String, dynamic> buildSettingsPayload() {
    final timerValue = int.tryParse(timerController.text.trim());
    return <String, dynamic>{
      'formTypeId': formTypeId,
      'showScore': showScore,
      'randomizeQuestions': randomizeQuestions,
      'oneResponse': oneResponse,
      'requiredLogin': requiredLogin,
      if (timerValue != null && timerValue > 0)
        'timerDuration':
            timerValue * (timerUnit == 'jam' ? 3600 : 60),
      if (tokenController.text.trim().isNotEmpty)
        'formToken': tokenController.text.trim(),
      if (openFormTime != null && !openTimeAlreadySet)
        'openFormTime': openFormTime!.toUtc().toIso8601String(),
      if (closeFormTime != null)
        'closeFormTime': closeFormTime!.toUtc().toIso8601String(),
    };
  }
}

/// Sanitasi link kustom: huruf kecil, angka, dan tanda hubung saja (maks 100).
String sanitizeFormLink(String value) {
  final v = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
  return v.length > 100 ? v.substring(0, 100) : v;
}
