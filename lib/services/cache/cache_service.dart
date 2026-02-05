import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CachedValue<T> {
  const CachedValue({
    required this.value,
    required this.updatedAt,
  });

  final T value;
  final DateTime updatedAt;
}

class CacheService {
  CacheService(this._preferences);

  final SharedPreferences _preferences;
  final Map<String, String> _memory = {};

  Future<CachedValue<T>?> read<T>(
    String key,
    T Function(Object? payload) decodePayload,
  ) async {
    final raw = _memory[key] ?? _preferences.getString(key);
    if (raw == null) {
      return null;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final updatedAtMillis = decoded['updatedAt'] as int?;
    final payload = decoded['payload'];
    if (updatedAtMillis == null) {
      return null;
    }

    return CachedValue<T>(
      value: decodePayload(payload),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMillis),
    );
  }

  Future<void> write<T>(
    String key,
    T value,
    Object? Function(T value) encodePayload,
  ) async {
    final encoded = jsonEncode({
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'payload': encodePayload(value),
    });
    _memory[key] = encoded;
    await _preferences.setString(key, encoded);
  }
}
