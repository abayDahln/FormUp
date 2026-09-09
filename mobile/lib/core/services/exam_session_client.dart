import 'dart:async';

import 'package:form_up/core/services/public_form_service.dart';

/// Klien sesi mode ujian untuk responden mobile.
///
/// Protokol (lihat api/documentation/endpoints/exam-monitoring.md):
/// - Kirim `session_start` sekali saat mulai mengerjakan; sessionId kosong
///   pada event pertama → server generate & kembalikan, dipakai ulang.
/// - `heartbeat` tiap 30 detik agar owner melihat status online.
///   Bila sessionId belum ada (start gagal) dikirim session_start agar
///   pulih ke sesi yang sama; gagal 1x dicoba lagi 5 detik kemudian.
/// - Tepat 1 event `tab_switch` per 1 siklus keluar-masuk (hanya saat
///   pergi/paused) — jangan kirim saat kembali agar tidak double-count.
/// - `shouldAutoSubmit=true` dari server → klien harus auto-submit.
class ExamSessionClient {
  final String formLink;
  final String? respondentName;

  String? sessionId;
  int tabSwitchCount = 0;
  int violationCount = 0;
  bool shouldAutoSubmit = false;
  bool _started = false;
  bool _stopped = false;
  Timer? _heartbeat;
  // Cegah tick heartbeat tumpang-tindih bila request lambat.
  bool _beatInflight = false;

  ExamSessionClient({required this.formLink, this.respondentName});

  bool get isActive => _started && !_stopped;

  /// Mulai sesi: kirim session_start + jadwalkan heartbeat.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final res = await PublicFormService.sendExamEvent(
        formLink,
        respondentName: respondentName,
        type: 'session_start',
      );
      sessionId = res.sessionId.isEmpty ? sessionId : res.sessionId;
      violationCount = res.violationCount;
      tabSwitchCount = res.tabSwitchCount;
      shouldAutoSubmit = res.shouldAutoSubmit;
    } catch (_) {
      // Offline/sesi gagal: pengerjaan tetap jalan (mode lokal).
    }
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) => _beat());
  }

  /// Satu detak presence: bila belum punya sessionId (session_start awal
  /// gagal, mis. offline/429 sesaat), kirim session_start agar sesi
  /// pulih ke SATU baris yang sama — bukan sesi baru tiap tick.
  /// Gagal → coba sekali lagi 5 detik kemudian (jendela online server
  /// 90 detik, jadi 1x miss masih aman).
  Future<void> _beat() async {
    if (_stopped || _beatInflight) return;
    _beatInflight = true;
    try {
      final res = await PublicFormService.sendExamEvent(
        formLink,
        sessionId: sessionId,
        respondentName: respondentName,
        type: sessionId == null ? 'session_start' : 'heartbeat',
      );
      if (res.sessionId.isNotEmpty) sessionId = res.sessionId;
      violationCount = res.violationCount;
      tabSwitchCount = res.tabSwitchCount;
      shouldAutoSubmit = res.shouldAutoSubmit;
    } catch (_) {
      try {
        await Future.delayed(const Duration(seconds: 5));
        if (_stopped) return;
        final res = await PublicFormService.sendExamEvent(
          formLink,
          sessionId: sessionId,
          respondentName: respondentName,
          type: sessionId == null ? 'session_start' : 'heartbeat',
        );
        if (res.sessionId.isNotEmpty) sessionId = res.sessionId;
        shouldAutoSubmit = res.shouldAutoSubmit;
      } catch (_) {}
    } finally {
      _beatInflight = false;
    }
  }

  /// Laporkan 1x keluar aplikasi. Mengembalikan true bila server
  /// meminta auto-submit (batas tercapai).
  Future<bool> reportTabSwitch() async {
    if (!_started || _stopped) return false;
    try {
      final res = await PublicFormService.sendExamEvent(
        formLink,
        sessionId: sessionId,
        respondentName: respondentName,
        type: 'tab_switch',
        occurredAt: DateTime.now(),
      );
      if (res.sessionId.isNotEmpty) sessionId = res.sessionId;
      violationCount = res.violationCount;
      tabSwitchCount = res.tabSwitchCount;
      shouldAutoSubmit = res.shouldAutoSubmit;
      return res.shouldAutoSubmit;
    } catch (_) {
      // Fallback lokal bila event gagal terkirim.
      tabSwitchCount++;
      return false;
    }
  }

  /// Laporkan 1x gangguan fokus/overlay (tipe `window_blur`).
  /// Dipakai untuk overlay/floating app & split-screen — dipetakan ke tipe
  /// lama yang diterima server (tanpa ubah API). Mengembalikan true bila
  /// server meminta auto-submit (batas tercapai).
  Future<bool> reportWindowBlur() async {
    if (!_started || _stopped) return false;
    try {
      final res = await PublicFormService.sendExamEvent(
        formLink,
        sessionId: sessionId,
        respondentName: respondentName,
        type: 'window_blur',
        occurredAt: DateTime.now(),
      );
      if (res.sessionId.isNotEmpty) sessionId = res.sessionId;
      violationCount = res.violationCount;
      tabSwitchCount = res.tabSwitchCount;
      shouldAutoSubmit = res.shouldAutoSubmit;
      return res.shouldAutoSubmit;
    } catch (_) {
      return false;
    }
  }

  void stop() {
    _stopped = true;
    _heartbeat?.cancel();
    _heartbeat = null;
  }
}
