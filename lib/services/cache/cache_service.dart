import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CachedValue<T> {
  const CachedValue({required this.value, required this.updatedAt});

  final T value;
  final DateTime updatedAt;
}

class CacheService {
  CacheService._(this._preferences, this._diskBox);

  static const _isFlutterTestFlag = bool.fromEnvironment('FLUTTER_TEST');
  static const _diskBoxName = 'neuws_cache_v2';
  static Future<Box<String>>? _openDiskBoxFuture;

  static Future<CacheService> create(SharedPreferences preferences) async {
    if (_isFlutterTestEnvironment) {
      return CacheService._(preferences, null);
    }
    final box = await _openDiskBox();
    return CacheService._(preferences, box);
  }

  static bool get _isFlutterTestEnvironment {
    if (_isFlutterTestFlag) {
      return true;
    }
    final bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding');
  }

  static Future<Box<String>> _openDiskBox() {
    _openDiskBoxFuture ??= () async {
      await Hive.initFlutter();
      if (Hive.isBoxOpen(_diskBoxName)) {
        return Hive.box<String>(_diskBoxName);
      }
      return Hive.openBox<String>(_diskBoxName);
    }();
    return _openDiskBoxFuture!;
  }

  final SharedPreferences _preferences;
  final Box<String>? _diskBox;
  final Map<String, String> _memory = {};

  Future<CachedValue<T>?> read<T>(
    String key,
    T Function(Object? payload) decodePayload,
  ) async {
    var raw = _memory[key] ?? _diskBox?.get(key);
    if (raw == null) {
      final legacyRaw = _preferences.getString(key);
      if (legacyRaw != null) {
        raw = legacyRaw;
        _memory[key] = legacyRaw;
        await _diskBox?.put(key, legacyRaw);
      }
    }
    if (raw == null) {
      return null;
    }

    try {
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
    } catch (_) {
      return null;
    }
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
    await _diskBox?.put(key, encoded);
    unawaited(_preferences.setString(key, encoded));
  }
}
