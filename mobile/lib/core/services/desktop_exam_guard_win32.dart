import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_exam_guard_stub.dart' show DesktopGuardState;

// ---- user32.dll bindings (minimal, hanya untuk melepas) ----

typedef _GetForegroundWindowNative = IntPtr Function();
typedef _GetForegroundWindowDart = int Function();

typedef _GetWindowTextWNative = Int32 Function(
    IntPtr hwnd, Pointer<Utf16> text, Int32 maxCount);
typedef _GetWindowTextWDart = int Function(
    int hwnd, Pointer<Utf16> text, int maxCount);

typedef _FindWindowWNative = IntPtr Function(Pointer<Utf16> className, Pointer<Utf16> windowName);
typedef _FindWindowWDart = int Function(Pointer<Utf16> className, Pointer<Utf16> windowName);

typedef _SetDisplayAffinityNative = Int32 Function(IntPtr hwnd, Uint32 affinity);
typedef _SetDisplayAffinityDart = int Function(int hwnd, int affinity);

typedef _GetDisplayAffinityNative = Int32 Function(IntPtr hwnd, Pointer<Uint32> affinity);
typedef _GetDisplayAffinityDart = int Function(int hwnd, Pointer<Uint32> affinity);

/// WDA_NONE: perilaku normal (konten terlihat di screenshot / capture, tidak hitam).
const int _wdaNone = 0x0;

/// Judul window aplikasi.
const List<String> _appWindowTitles = ['FormUp', 'form_up', 'Form Up'];

/// Implementasi exam desktop: window_manager (fullscreen, always-on-top,
/// prevent-close). Screenshot TIDAK diblokir — hanya dicatat sebagai
/// pelanggaran lewat WindowListener di form runner bila fokus hilang
/// cukup lama. Semua best-effort: gagal = false, tidak pernah melempar.
class DesktopExamGuardImpl {
  /// Penyembuh satu arah: kembalikan affinity window ke normal (WDA_NONE = 0x0)
  /// bila masih membawa setelan hitam dari build lama.
  /// TIDAK PERNAH memasang blokir — hanya melepas. Status dibaca balik
  /// via GetWindowDisplayAffinity dan dicatat ke console ([DesktopGuard])
  /// agar mudah didiagnosis.
  static Future<void> _clearStaleAffinity() async {
    if (!Platform.isWindows) return;
    // Coba beberapa kali: saat startup judul window kadang belum siap.
    for (var attempt = 0; attempt < 6; attempt++) {
      if (await _clearStaleAffinityOnce()) return;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    debugPrint('[DesktopGuard] healer: window tak ditemukan setelah 6x coba');
  }

  static Future<bool> _clearStaleAffinityOnce() async {
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final getForeground = user32.lookupFunction<_GetForegroundWindowNative,
          _GetForegroundWindowDart>('GetForegroundWindow');
      final getText = user32.lookupFunction<_GetWindowTextWNative,
          _GetWindowTextWDart>('GetWindowTextW');
      final findWindow = user32.lookupFunction<_FindWindowWNative,
          _FindWindowWDart>('FindWindowW');
      final setAffinity = user32.lookupFunction<_SetDisplayAffinityNative,
          _SetDisplayAffinityDart>('SetWindowDisplayAffinity');
      final getAffinity = user32.lookupFunction<_GetDisplayAffinityNative,
          _GetDisplayAffinityDart>('GetWindowDisplayAffinity');

      bool titleOk(int hwnd) {
        final buf = calloc<Uint16>(256).cast<Utf16>();
        try {
          final len = getText(hwnd, buf, 256);
          if (len <= 0) return false;
          final title = buf.toDartString(length: len);
          return _appWindowTitles.contains(title);
        } finally {
          calloc.free(buf);
        }
      }

      int readAffinity(int hwnd) {
        final out = calloc<Uint32>();
        try {
          final ok = getAffinity(hwnd, out);
          return ok != 0 ? out.value : -1;
        } finally {
          calloc.free(out);
        }
      }

      int hwnd = getForeground();
      if (hwnd == 0 || !titleOk(hwnd)) {
        hwnd = 0;
        for (final titleStr in _appWindowTitles) {
          final titlePtr = titleStr.toNativeUtf16();
          try {
            final classPtr = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
            try {
              hwnd = findWindow(classPtr, titlePtr);
            } finally {
              calloc.free(classPtr);
            }
            if (hwnd == 0) hwnd = findWindow(nullptr, titlePtr);
          } finally {
            calloc.free(titlePtr);
          }
          if (hwnd != 0 && titleOk(hwnd)) break;
        }
        if (hwnd == 0 || !titleOk(hwnd)) return false;
      }
      final before = readAffinity(hwnd);
      if (before == _wdaNone) {
        debugPrint('[DesktopGuard] healer: affinity sudah normal (WDA_NONE, hwnd=$hwnd)');
        return true;
      }
      final ok = setAffinity(hwnd, _wdaNone);
      final after = readAffinity(hwnd);
      debugPrint('[DesktopGuard] healer: $before -> $after (ok=$ok, hwnd=$hwnd)');
      return ok != 0 && after == _wdaNone;
    } catch (e) {
      debugPrint('[DesktopGuard] healer gagal: $e');
      return false;
    }
  }

  static Future<bool> _setFullscreen(bool enabled) async {
    try {
      await windowManager.setFullScreen(enabled);
      await windowManager.setAlwaysOnTop(enabled);
      await windowManager.setPreventClose(enabled);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[DesktopGuard] fullscreen gagal: $e');
      return false;
    }
  }

  static Future<DesktopGuardState> enterExamWindow() async {
    // Pastikan tidak ada sisa blokir dari build lama sebelum ujian mulai.
    await _clearStaleAffinity();
    final fullscreen = await _setFullscreen(true);
    return DesktopGuardState(fullscreen: fullscreen);
  }

  static Future<void> exitExamWindow() async {
    // Dipanggil juga saat startup: menyembuhkan window yang stuck hitam.
    await _clearStaleAffinity();
    try {
      await windowManager.setPreventClose(false);
    } catch (_) {}
    try {
      await windowManager.setAlwaysOnTop(false);
    } catch (_) {}
    try {
      await windowManager.setFullScreen(false);
    } catch (_) {}
  }

  /// No-op (dulu menegakkan ulang anti-screenshot yang kini dihapus).
  /// Dipertahankan agar pemanggil lama tidak rusak.
  static Future<void> reassertAffinity() async {}
}
