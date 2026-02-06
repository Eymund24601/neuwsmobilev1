import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  SupabaseBootstrap._();

  static bool _initialized = false;
  static String? _resolvedUrl;
  static String? _resolvedAnonKey;

  static bool get isConfigured =>
      (_resolvedUrl ?? _readUrl()) != null &&
      (_resolvedAnonKey ?? _readAnonKey()) != null;

  static bool get isInitialized => _initialized;

  static Future<void> initializeIfConfigured() async {
    if (_initialized) {
      return;
    }

    _resolvedUrl = _readUrl();
    _resolvedAnonKey = _readAnonKey();
    if (_resolvedUrl == null || _resolvedAnonKey == null) {
      return;
    }

    await Supabase.initialize(
      url: _resolvedUrl!,
      anonKey: _resolvedAnonKey!,
      debug: kDebugMode,
    );
    _initialized = true;
  }

  static String? _readUrl() {
    const direct = String.fromEnvironment('SUPABASE_URL');
    final directValue = direct.trim();
    if (_isUsableValue(directValue) && _looksLikeUrl(directValue)) {
      return directValue;
    }
    const nextStyle = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_URL');
    final nextStyleValue = nextStyle.trim();
    if (_isUsableValue(nextStyleValue) && _looksLikeUrl(nextStyleValue)) {
      return nextStyleValue;
    }
    return null;
  }

  static String? _readAnonKey() {
    const direct = String.fromEnvironment('SUPABASE_ANON_KEY');
    final directValue = direct.trim();
    if (_isUsableValue(directValue)) {
      return directValue;
    }
    const nextStyle = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_ANON_KEY');
    final nextStyleValue = nextStyle.trim();
    if (_isUsableValue(nextStyleValue)) {
      return nextStyleValue;
    }
    return null;
  }

  static bool _isUsableValue(String value) {
    if (value.isEmpty) {
      return false;
    }
    final normalized = value.toLowerCase();
    return !normalized.contains('your_') &&
        !normalized.contains('change_me') &&
        !normalized.contains('example');
  }

  static bool _looksLikeUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  }
}
