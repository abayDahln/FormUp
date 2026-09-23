import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:form_up/core/services/network_status.dart';

class OfflineCacheException implements Exception {
  final String message;
  const OfflineCacheException(this.message);

  @override
  String toString() => message;
}

/// True bila [e] adalah error koneksi/jaringan (bukan 404/validasi/data).
/// Cerminan ringkas `AuthService.isConnectionError` — didefinisikan di sini
/// agar tidak terjadi import sirkular (auth_service mengimpor api_cache).
bool isApiConnectionError(Object e) {
  if (e is OfflineCacheException) return true;
  if (e is TimeoutException || e is SocketException || e is http.ClientException) {
    return true;
  }
  final msg = e.toString().toLowerCase();
  return msg.contains('gagal terhubung') ||
      msg.contains('kamu sedang offline') ||
      msg.contains('sedang offline') ||
      msg.contains('periksa koneksi') ||
      msg.contains('koneksi internet') ||
      msg.contains('gangguan pada layanan') ||
      msg.contains('tidak ada koneksi') ||
      msg.contains('connection') ||
      msg.contains('socket') ||
      msg.contains('timeout') ||
      msg.contains('timed out') ||
      msg.contains('network') ||
      msg.contains('jaringan');
}

class _ApiCacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  const _ApiCacheEntry({
    required this.value,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Cache ringan untuk hasil request yang sering dibaca ulang.
///
/// Strategi network-first + fallback:
/// 1. Memory masih fresh (dalam TTL) → langsung sajikan (hemat request,
///    dedup tab bolak-balik).
/// 2. Selain itu selalu coba API dulu.
/// 3. API gagal (rate-limit 429 / 5xx / timeout / offline) → fallback ke
///    memory basi bila ada.
/// 4. Offline → boleh sajikan disk (boleh stale, agar aplikasi tetap
///    usable); online → TIDAK PERNAH sajikan disk basi, error
///    diteruskan agar data basi tidak tampil diam-diam.
class ApiCache {
  static final Map<String, _ApiCacheEntry<Object?>> _cache = {};
  static final Map<String, Completer<Object?>> _pending = {};
  static const String _diskStoreKey = 'api_cache_v1';

  static DateTime _now() => DateTime.now();

  static Future<Map<String, dynamic>> _readDiskStore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_diskStoreKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  static Future<void> _writeDiskStore(Map<String, dynamic> store) async {
    final prefs = await SharedPreferences.getInstance();
    if (store.isEmpty) {
      await prefs.remove(_diskStoreKey);
      return;
    }
    await prefs.setString(_diskStoreKey, jsonEncode(store));
  }

  static dynamic _decodeDiskValue(Map<String, dynamic> entry) {
    final expiresRaw = entry['expiresAt'] as String?;
    final value = entry['value'];
    if (expiresRaw == null || value == null) return null;
    final expiresAt = DateTime.tryParse(expiresRaw);
    if (expiresAt == null) return null;
    final expired = _now().isAfter(expiresAt);
    if (NetworkStatus.isOnline && expired) return null;
    return value;
  }

  // Poin 7: jangan persist data sensitif ke disk (SharedPreferences plaintext).
  // Data live (monitoring/hasil/attempt) juga dikecualikan agar tidak
  // disajikan basi berhari-hari dari disk saat offline/stale.
  // Profil (/users/me, /users/me/stats) BOLEH persist: hanya nama/email/foto
  // (tanpa password/token, disetujui pemilik) agar tampil instan setelah
  // restart; logout selalu menghapus seluruh disk cache via clear().
  static bool _isSensitiveKey(String key) {
    final k = key.toLowerCase();
    return k.contains('responses') || k.contains('analytics') || k.contains('attempts') || k.contains('response') || k.contains('admin') || k.contains('monitoring') || k.contains('result');
  }

  static Future<void> _persistValue(
    String key,
    Object? value,
    Duration ttl,
  ) async {
    if (_isSensitiveKey(key)) return;
    try {
      jsonEncode(value);
    } catch (_) {
      return;
    }

    // Disk TTL lebih panjang dari memory TTL agar bisa dipakai mode offline
    // hingga 7 hari meski memory sudah expired (20-60 detik).
    final diskTtl = ttl.inSeconds < 3600 ? const Duration(days: 7) : ttl;
    final store = await _readDiskStore();
    store[key] = <String, dynamic>{
      'expiresAt': _now().add(diskTtl).toUtc().toIso8601String(),
      'value': value,
    };
    await _writeDiskStore(store);
  }

  /// completeError + pasang no-op listener. Caller PERTAMA tidak pernah
  /// meng-await completer dedup ini (dia menunggu loader langsung), jadi
  /// kalau tidak ada caller duplikat bersamaan, completer future tidak punya
  /// listener — error-nya jadi "Unhandled Exception" di console meskipun UI
  /// sudah menanganinya lewat rethrow.
  static void _completeErrorSafe(
    Completer<Object?> completer,
    Object error,
    StackTrace st,
  ) {
    if (completer.isCompleted) return;
    completer.completeError(error, st);
    completer.future.catchError((_) => null);
  }

  static Future<T> _loadAndCache<T>(
    String key,
    Duration ttl,
    Future<T> Function() loader,
  ) async {
    final value = await loader();
    _cache[key] = _ApiCacheEntry<Object?>(
      value: value,
      expiresAt: _now().add(ttl),
    );
    await _persistValue(key, value, ttl);
    NetworkStatus.markOnline();
    return value;
  }

  /// Baca satu entri disk (sudah diputuskan boleh dipakai oleh pemanggil).
  /// Mengembalikan null bila tidak ada / tidak bisa di-decode.
  static Future<T?> _readDisk<T>(String key, Duration ttl) async {
    final store = await _readDiskStore();
    final entry = store[key];
    if (entry is Map<String, dynamic>) {
      final value = _decodeDiskValue(entry);
      if (value != null) {
        _cache[key] = _ApiCacheEntry<Object?>(
          value: value,
          expiresAt: _now().add(ttl),
        );
        return value as T;
      }
    }
    return null;
  }

  static Future<T> get<T>(
    String key,
    Duration ttl,
    Future<T> Function() loader,
  ) async {
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.value as T;
    }
    final expiredMemory = cached?.value;

    // Offline sejak awal: sajikan disk (boleh stale) tanpa hit API,
    // lalu memory basi; terakhir coba sekali siapa tahu sudah online.
    if (NetworkStatus.isOffline) {
      await NetworkStatus.refresh();
      if (NetworkStatus.isOffline) {
        final diskValue = await _readDisk<T>(key, ttl);
        if (diskValue != null) return diskValue;
        if (expiredMemory != null) {
          _cache[key] = _ApiCacheEntry<Object?>(
            value: expiredMemory,
            expiresAt: _now().add(ttl),
          );
          return expiredMemory as T;
        }
        try {
          return await _loadAndCache<T>(key, ttl, loader);
        } catch (e) {
          // Hanya error koneksi yang dipetakan ke pesan offline.
          // Error non-koneksi (404/validasi) diteruskan apa adanya agar
          // tidak disamarkan menjadi "offline".
          if (isApiConnectionError(e)) {
            throw const OfflineCacheException(
              'Kamu sedang offline. Periksa koneksi internet dan coba lagi.',
            );
          }
          rethrow;
        }
      }
    }

    final existing = _pending[key];
    if (existing != null) {
      return await existing.future as T;
    }

    final completer = Completer<Object?>();
    _pending[key] = completer;
    try {
      // Network-first: selalu coba API bila memory tidak fresh.
      final value = await _loadAndCache<T>(key, ttl, loader);
      completer.complete(value);
      return value;
    } catch (e, st) {
      // API gagal (rate-limit/offline/5xx/timeout): fallback memory basi.
      if (expiredMemory != null) {
        _cache[key] = _ApiCacheEntry<Object?>(
          value: expiredMemory,
          expiresAt: _now().add(ttl),
        );
        if (!completer.isCompleted) completer.complete(expiredMemory);
        return expiredMemory as T;
      }
      // Tanpa memory: cek benar-benar offline → boleh sajikan disk stale.
      // Online → JANGAN sajikan disk basi; teruskan error aslinya.
      try {
        await NetworkStatus.refresh();
      } catch (_) {}
      if (NetworkStatus.isOffline) {
        final diskValue = await _readDisk<T>(key, ttl);
        if (diskValue != null) {
          if (!completer.isCompleted) completer.complete(diskValue);
          return diskValue;
        }
        _completeErrorSafe(
          completer,
          const OfflineCacheException('Kamu sedang offline. Periksa koneksi internet dan coba lagi.'),
          st,
        );
        throw const OfflineCacheException('Kamu sedang offline. Periksa koneksi internet dan coba lagi.');
      }
      _completeErrorSafe(completer, e, st);
      rethrow;
    } finally {
      _pending.remove(key);
    }
  }

  static void invalidate(String key) {
    _cache.remove(key);
    _pending.remove(key);
    unawaited(_removeFromDisk(key));
  }

  static void invalidatePrefix(String prefix) {
    _cache.removeWhere((key, _) => key.startsWith(prefix));
    _pending.removeWhere((key, _) => key.startsWith(prefix));
    unawaited(_removePrefixFromDisk(prefix));
  }

  /// D6: invalidate semua entri yang mengandung substring (mis. '/users/me'),
  /// tanpa tahu scope akun persisnya.
  static void invalidateContaining(String substring) {
    final sub = substring.toLowerCase();
    _cache.removeWhere((key, _) => key.toLowerCase().contains(sub));
    _pending.removeWhere((key, _) => key.toLowerCase().contains(sub));
    unawaited(_removeContainingFromDisk(sub));
  }

  static Future<void> _removeContainingFromDisk(String substring) async {
    final store = await _readDiskStore();
    final before = store.length;
    store.removeWhere((key, _) => key.toLowerCase().contains(substring));
    if (store.length != before) {
      await _writeDiskStore(store);
    }
  }

  static Future<void> _removeFromDisk(String key) async {
    final store = await _readDiskStore();
    if (store.remove(key) != null) {
      await _writeDiskStore(store);
    }
  }

  static Future<void> _removePrefixFromDisk(String prefix) async {
    final store = await _readDiskStore();
    final before = store.length;
    store.removeWhere((key, _) => key.startsWith(prefix));
    if (store.length != before) {
      await _writeDiskStore(store);
    }
  }

  static Future<void> clear() async {
    _cache.clear();
    _pending.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_diskStoreKey);
  }
}
