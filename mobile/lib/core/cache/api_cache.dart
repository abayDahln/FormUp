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

  static Future<void> _persistValue(
    String key,
    Object? value,
    Duration ttl,
  ) async {
    try {
      jsonEncode(value);
    } catch (_) {
      return;
    }

    final store = await _readDiskStore();
    store[key] = <String, dynamic>{
      'expiresAt': _now().add(ttl).toUtc().toIso8601String(),
      'value': value,
    };
    await _writeDiskStore(store);
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
      throw const OfflineCacheException(
        'Kamu sedang offline dan data ini belum ada di cache.',
      );
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
      completer.complete(value);
      return value;
    } catch (e, st) {
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
            if (!completer.isCompleted) completer.complete(value);
            return value as T;
          }
        }
      }
      if (!completer.isCompleted) completer.completeError(e, st);
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
