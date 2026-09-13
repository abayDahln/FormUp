import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_exam_guard_stub.dart' show DesktopGuardState;

// ---- user32.dll bindings (minimal, tanpa package tambahan) ----

typedef _GetForegroundWindowNative = IntPtr Function();
typedef _GetForegroundWindowDart = int Function();

typedef _GetWindowTextWNative = Int32 Function(
    IntPtr hwnd, Pointer<Utf16> text, Int32 maxCount);
typedef _GetWindowTextWDart = int Function(
    int hwnd, Pointer<Utf16> text, int maxCount);

typedef _SetDisplayAffinityNative = Int32 Function(IntPtr hwnd, Uint32 affinity);
typedef _SetDisplayAffinityDart = int Function(int hwnd, int affinity);

/// WDA_EXCLUDEFROMCAPTURE: konten jendela hitam di screenshot / Snipping
/// Tool / Game Bar / perekam layar. WDA_MONITOR: perilaku normal.
const int _wdaExcludeFromCapture = 0x11;
const int _wdaMonitor = 0x1;

/// Judul window aplikasi (diset window_manager di main.dart).
const String _appWindowTitle = 'FormUp';

/// Implementasi exam desktop: window_manager (fullscreen, always-on-top,
/// prevent-close) + FFI user32 (SetWindowDisplayAffinity anti-screenshot).
/// Semua best-effort: gagal = false, tidak pernah melempar.
class DesktopExamGuardImpl {
  static DynamicLibrary? _user32;
  static _GetForegroundWindowDart? _getForegroundWindow;
  static _GetWindowTextWDart? _getWindowText;
  static _SetDisplayAffinityDart? _setDisplayAffinity;

  static bool _bindUser32() {
    if (!Platform.isWindows) return false;
    try {
      if (_setDisplayAffinity != null) return true;
      _user32 ??= DynamicLibrary.open('user32.dll');
      final lib = _user32!;
      _getForegroundWindow = lib.lookupFunction<_GetForegroundWindowNative,
          _GetForegroundWindowDart>('GetForegroundWindow');
      _getWindowText = lib
          .lookupFunction<_GetWindowTextWNative, _GetWindowTextWDart>(
              'GetWindowTextW');
      _setDisplayAffinity = lib.lookupFunction<_SetDisplayAffinityNative,
          _SetDisplayAffinityDart>('SetWindowDisplayAffinity');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[DesktopGuard] bind user32 gagal: $e');
      return false;
    }
  }

  /// Terapkan affinity pada window aplikasi sendiri. Window diverifikasi
  /// lewat judul agar tidak salah sasaran bila fokus sudah pindah.
  static bool _applyAffinity(bool exclude) {
    try {
      if (!_bindUser32()) return false;
      final hwnd = _getForegroundWindow!.call();
      if (hwnd == 0) return false;
      final buf = calloc<Uint16>(256).cast<Utf16>();
      try {
        final len = _getWindowText!.call(hwnd, buf, 256);
        if (len <= 0) return false;
        if (buf.toDartString(length: len) != _appWindowTitle) return false;
        final ok = _setDisplayAffinity!.call(
            hwnd, exclude ? _wdaExcludeFromCapture : _wdaMonitor);
        return ok != 0;
      } finally {
        calloc.free(buf);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[DesktopGuard] affinity gagal: $e');
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
    final fullscreen = await _setFullscreen(true);
    // Affinity setelah fullscreen: window pasti foreground milik sendiri.
    // Non-Windows: _bindUser32 gagal → affinity false (lapor jujur).
    final affinity = _applyAffinity(true);
    return DesktopGuardState(fullscreen: fullscreen, affinity: affinity);
  }

  static Future<void> exitExamWindow() async {
    try {
      _applyAffinity(false);
    } catch (_) {}
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

  /// Tegakkan ulang affinity saat window kembali fokus (murah & sunyi:
  /// tanpa toast — kegagalan awal sudah dilaporkan saat ujian mulai).
  static Future<void> reassertAffinity() async {
    if (!Platform.isWindows) return;
    try {
      _applyAffinity(true);
    } catch (_) {}
  }
}
