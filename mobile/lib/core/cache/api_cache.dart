import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:form_up/core/services/network_status.dart';

class OfflineCacheException implements Exception {
  final String message;
  const OfflineCacheException(this.message);

  @override
  String toString() => message;
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

/// Cache in-memory ringan untuk hasil request yang sering dibaca ulang.
///
/// Dipakai untuk mengurangi fetch berulang saat user bolak-balik screen,
/// tanpa menambah storage permanen atau membuat data terlalu lama basi.
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
  static bool _isSensitiveKey(String key) {
    final k = key.toLowerCase();
    return k.contains('responses') || k.contains('analytics') || k.contains('attempts') || k.contains('response') || k.contains('admin') || k.contains('users:me');
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

  static Future<T> get<T>(
    String key,
    Duration ttl,
    Future<T> Function() loader,
  ) async {
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.value as T;
    }

    if (NetworkStatus.isOffline) {
      await NetworkStatus.refresh();
      if (NetworkStatus.isOffline) {
        final store = await _readDiskStore();
        final entry = store[key];
        if (entry is Map<String, dynamic>) {
          final value = _decodeDiskValue(entry);
          if (value != null) {
            _cache[key] = _ApiCacheEntry<Object?>(
              value: value,
              expiresAt: DateTime.now().add(ttl),
            );
            return value as T;
          }
        }
        try {
          final attempted = await loader();
          NetworkStatus.markOnline();
          _cache[key] = _ApiCacheEntry<Object?>(
            value: attempted,
            expiresAt: DateTime.now().add(ttl),
          );
          await _persistValue(key, attempted, ttl);
          return attempted;
        } catch (_) {
          throw const OfflineCacheException(
            'Kamu sedang offline. Periksa koneksi internet dan coba lagi.',
          );
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
      final value = await loader();
      _cache[key] = _ApiCacheEntry<Object?>(
        value: value,
        expiresAt: DateTime.now().add(ttl),
      );
      await _persistValue(key, value, ttl);
      NetworkStatus.markOnline();
      completer.complete(value);
      return value;
    } catch (e, st) {
      // Fallback ke disk stale saat loader gagal (server down padahal NetworkStatus masih online)
      // – sebelumnya hanya fallback saat isOffline, sehingga data tidak muncul saat server offline.
      final store = await _readDiskStore();
      final entry = store[key];
      if (entry is Map<String, dynamic>) {
        final rawEntry = entry;
        final value = _decodeDiskValue(rawEntry);
        // Jika online tapi expired, _decodeDiskValue return null – coba ambil stale tanpa cek expired
        dynamic stale = value;
        if (stale == null && rawEntry['value'] != null) {
          stale = rawEntry['value'];
        }
        if (stale != null) {
          _cache[key] = _ApiCacheEntry<Object?>(
            value: stale,
            expiresAt: DateTime.now().add(ttl),
          );
          if (!completer.isCompleted) completer.complete(stale);
          // Tandai bahwa kita sedang dalam mode offline-stale
          return stale as T;
        }
      }
      // Coba refresh status jaringan sekali – jika ternyata offline, lempar OfflineCacheException yang ramah
      try {
        await NetworkStatus.refresh();
      } catch (_) {}
      if (NetworkStatus.isOffline) {
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
