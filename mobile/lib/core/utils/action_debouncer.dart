/// Debounce/throttle 300ms konsisten untuk aksi UI dan panggilan API.
/// Dipakai di tombol (login, regis, send, save, submit, import, delete, dsb.)
/// serta di `AuthService` / `FormService` agar fetch konsisten dan anti spam-klik.
class AppDebouncer {
  /// Durasi tunggal 300ms — sumber kebenaran untuk UI + service.
  static const Duration kDebounce = Duration(milliseconds: 300);

  static final Map<String, DateTime> _last = {};

  /// true bila aksi boleh lanjut; false bila masih dalam jendela debounce (abaikan).
  static bool tryAcquire(String key, {Duration? window}) {
    final now = DateTime.now();
    final w = window ?? kDebounce;
    final prev = _last[key];
    if (prev != null && now.difference(prev) < w) return false;
    _last[key] = now;
    return true;
  }

  /// Reset manual (mis. setelah logout).
  static void clear([String? key]) {
    if (key == null) {
      _last.clear();
    } else {
      _last.remove(key);
    }
  }
}
