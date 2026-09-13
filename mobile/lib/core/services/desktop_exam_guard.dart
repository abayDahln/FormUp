import 'desktop_exam_guard_stub.dart'
    if (dart.library.io) 'desktop_exam_guard_win32.dart'
    as _impl;

import 'desktop_exam_guard_stub.dart'
    show DesktopGuardState;

/// Pengaman ujian desktop (Windows; no-op di mobile/web).
///
/// - [enterExamWindow]: fullscreen + always-on-top + prevent-close
///   (window_manager). Screenshot TIDAK diblokir; pelanggaran fokus
///   dicatat via WindowListener di form runner. Kembalikan status
///   per-lapisan agar caller memberi tahu user bila ada yang gagal
///   (jangan diam seolah terkunci penuh).
/// - [exitExamWindow]: kembalikan semuanya (wajib di semua jalur keluar).
/// - [reassertAffinity]: no-op (sisa kompatibilitas).
/// Semua best-effort, tidak pernah melempar.
class DesktopExamGuard {
  static Future<DesktopGuardState> enterExamWindow() =>
      _impl.DesktopExamGuardImpl.enterExamWindow();

  static Future<void> exitExamWindow() =>
      _impl.DesktopExamGuardImpl.exitExamWindow();

  static Future<void> reassertAffinity() =>
      _impl.DesktopExamGuardImpl.reassertAffinity();
}
