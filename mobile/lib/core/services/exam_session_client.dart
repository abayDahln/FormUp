import 'dart:async';

import 'package:form_up/core/services/public_form_service.dart';

/// Klien sesi mode ujian untuk responden mobile.
///
/// Protokol (lihat api/documentation/endpoints/exam-monitoring.md):
/// - Kirim `session_start` sekali saat mulai mengerjakan; sessionId kosong
///   pada event pertama → server generate & kembalikan, dipakai ulang.
/// - `heartbeat` tiap 5 detik agar owner melihat status online dan
///   runner cepat mendeteksi auto-submit/force-submit (real-time).
///   Bila sessionId belum ada (start gagal) dikirim session_start agar
///   pulih ke sesi yang sama; gagal 1x dicoba lagi 5 detik kemudian.
/// - Tepat 1 event `tab_switch` per 1 siklus keluar-masuk (hanya saat
///   pergi/paused) — jangan kirim saat kembali agar tidak double-count.
/// - `shouldAutoSubmit=true` dari server → klien harus auto-submit.
class ExamSessionClient {
  final String formLink;
  final String? respondentName;

  /// Penyedia jawaban terkini (format submit) untuk sync draft berkala.
  /// Diisi runner screen dari answer store; null = sync draft nonaktif.
  List<Map<String, dynamic>> Function()? answerProvider;

  String? sessionId;
  int tabSwitchCount = 0;
  int violationCount = 0;
  bool shouldAutoSubmit = false;

  /// Dipanggil sekali saat server meminta auto-submit di luar jalur lapor
  /// pelanggaran (heartbeat/session_start) — paritas web yang mengecek
  /// shouldAutoSubmit di setiap respons exam-event. Tanpa ini, limit yang
  /// tercapai tanpa laporan lokal baru tak pernah memicu auto-submit.
  Future<void> Function()? onShouldAutoSubmit;

  /// Dipanggil sekali saat sesi ternyata sudah disubmit/diakhiri pengawas
  /// (sync draft balas 400 "Sesi sudah disubmit"). Layar wajib TIDAK
  /// mengirim ulang — cukup informasikan user lalu keluar.
  Future<void> Function()? onSessionTerminated;

  /// Dipanggil saat sesi ternyata sudah dihapus pengawas (reset):
  /// client mereset state lokal lalu layar memulihkan UI agar responden
  /// bisa mulai baru (sesi baru dibuat otomatis di heartbeat berikut).
  /// Berbeda dengan terminasi (sudah disubmit → keluar).
  Future<void> Function()? onSessionReset;

  bool _notifiedAutoSubmit = false;
  bool _notifiedTerminated = false;
  bool _resetNotified = false;
  bool _started = false;
  bool _stopped = false;
  Timer? _heartbeat;
  // Cegah tick heartbeat tumpang-tindih bila request lambat.
  bool _beatInflight = false;
  // Interval heartbeat real-time: deteksi auto-submit/force-submit ≤5 dtk.
  // Aman terhadap rate limiter (12 req/mnt per sesi, batas 60/mnt/IP/form).
  static const heartbeatInterval = Duration(seconds: 5);

  ExamSessionClient({required this.formLink, this.respondentName, this.answerProvider});

  bool get isActive => _started && !_stopped;

  /// True bila error berarti sesi sudah disubmit/diakhiri (paritas web:
  /// sync 400 "Sesi sudah disubmit", submit 409 "Sesi sudah disubmit
  /// pengawas."). ApiException hanya membawa pesan, jadi deteksi via
  /// teks seperti web.
  static bool isSessionEndedError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('disubmit');
  }

  /// True bila hasil event menandakan sesi sudah disubmit/diakhiri.
  static bool isTerminatedResult(ExamEventResult res) => res.isTerminated;

  /// Catat hasil event + picu callback terminasi bila sesi sudah berakhir.
  /// Dipakai semua jalur sukses (start/beat/lapor) agar deteksi force-submit
  /// maksimal 1 event, bukan menunggu sync berikutnya.
  Future<void> _noteResult(ExamEventResult res) async {
    if (isTerminatedResult(res)) await _fireTerminated();
  }

  Future<void> _fireAutoSubmit() async {
    if (_notifiedAutoSubmit || _stopped) return;
    _notifiedAutoSubmit = true;
    final cb = onShouldAutoSubmit;
    if (cb == null) return;
    try {
      await cb();
    } catch (_) {}
  }

  Future<void> _fireTerminated() async {
    if (_notifiedTerminated || _stopped) return;
    _notifiedTerminated = true;
    final cb = onSessionTerminated;
    if (cb == null) return;
    try {
      await cb();
    } catch (_) {}
  }

  /// True bila error berarti sesi sudah di-reset pengawas (404 reset).
  /// Berbeda dari terminated: sesi hilang, responden boleh mulai baru.
  static bool isResetError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('reset') && !msg.contains('disubmit');
  }

  /// Reset state lokal setelah reset pengawas. Sesi baru dibuat otomatis
  /// (session_start tanpa id) di detak berikutnya.
  void _resetLocalState() {
    sessionId = null;
    tabSwitchCount = 0;
    violationCount = 0;
    shouldAutoSubmit = false;
    _notifiedAutoSubmit = false;
    _notifiedTerminated = false;
  }

  Future<void> _fireReset() async {
    // Satu insiden = satu notifikasi; dibuka lagi setelah sesi baru terbentuk.
    if (_resetNotified || _stopped) return;
    _resetNotified = true;
    final cb = onSessionReset;
    if (cb == null) return;
    try {
      await cb();
    } catch (_) {}
  }

  /// Tangani error event/sync: reset (sesi dihapus) vs terminated
  /// (sudah disubmit) vs gangguan biasa (offline). Mengembalikan true
  /// bila sudah ditangani sebagai reset/terminated — pemanggil wajib
  /// melewati fallback counter lokal agar tak menambah pelanggaran hantu.
  Future<bool> _handleEventError(Object e) async {
    if (isResetError(e)) {
      _resetLocalState();
      await _fireReset();
      return true;
    }
    if (isSessionEndedError(e)) {
      await _fireTerminated();
      return true;
    }
    return false;
  }

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
      await _noteResult(res);
      // Sesi hidup kembali (baru dibuat) → reset berikutnya boleh notif lagi.
      _resetNotified = false;
    } catch (e) {
      // Offline/sesi gagal: pengerjaan tetap jalan (mode lokal).
      await _handleEventError(e);
    }
    if (shouldAutoSubmit) await _fireAutoSubmit();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _beat());
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
      await _noteResult(res);
      _resetNotified = false;
    } catch (e) {
      if (await _handleEventError(e)) return;
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
        // C9: jalur retry samakan 4 field seperti jalur utama —
        // sebelumnya limit/badge/pantau telat 1 detak heartbeat.
        violationCount = res.violationCount;
        tabSwitchCount = res.tabSwitchCount;
        shouldAutoSubmit = res.shouldAutoSubmit;
        await _noteResult(res);
        _resetNotified = false;
      } catch (e2) {
        await _handleEventError(e2);
      }
    } finally {
      _beatInflight = false;
    }
    if (shouldAutoSubmit) await _fireAutoSubmit();
    // Sync draft jawaban (Spec B12) — best-effort tiap heartbeat.
    await syncDraft();
  }

  /// Kirim draft jawaban terkini ke server (best-effort, abaikan gagal).
  /// Dipanggil tiap heartbeat + bisa dipanggil manual (mis. tiap ganti soal).
  /// Selalu ping walau jawaban kosong (paritas web forceCheck): cek
  /// SubmittedResponseId server jalan sebelum validasi isi, sehingga
  /// responden idle pun tetap mendeteksi force-submit pengawas.
  Future<void> syncDraft() async {
    final provider = answerProvider;
    final id = sessionId;
    if (_stopped || provider == null || id == null || id.isEmpty) return;
    try {
      final answers = provider();
      await PublicFormService.syncExamAnswers(
        formLink,
        id,
        respondentName: respondentName,
        answers: answers,
      );
    } catch (e) {
      // Reset/terminated/dibuang hening; offline murni diabaikan (best-effort).
      await _handleEventError(e);
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
      // Layar menangani langsung via nilai balik; cegah heartbeat
      // memicu callback yang sama untuk kedua kalinya.
      if (res.shouldAutoSubmit) _notifiedAutoSubmit = true;
      await _noteResult(res);
      _resetNotified = false;
      return res.shouldAutoSubmit;
    } catch (e) {
      // Reset/terminated sudah ditangani; offline = fallback lokal.
      if (await _handleEventError(e)) return false;
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
      // Layar menangani langsung via nilai balik; cegah heartbeat
      // memicu callback yang sama untuk kedua kalinya.
      if (res.shouldAutoSubmit) _notifiedAutoSubmit = true;
      await _noteResult(res);
      _resetNotified = false;
      return res.shouldAutoSubmit;
    } catch (e) {
      // Reset/terminated sudah ditangani; offline = fallback lokal (C3).
      if (await _handleEventError(e)) return false;
      // C3: offline = pelanggaran hilang. Naikkan counter lokal (belum
      // tersinkron) seperti reportTabSwitch — diselaraskan ulang dari
      // server saat event berikutnya berhasil terkirim.
      tabSwitchCount++;
      violationCount++;
      return false;
    }
  }

  void stop() {
    _stopped = true;
    _heartbeat?.cancel();
    _heartbeat = null;
  }
}
