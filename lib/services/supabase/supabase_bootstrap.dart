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
    if (direct.trim().isNotEmpty) {
      return direct.trim();
    }
    const nextStyle = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_URL');
    if (nextStyle.trim().isNotEmpty) {
      return nextStyle.trim();
    }
    return null;
  }

  static String? _readAnonKey() {
    const direct = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (direct.trim().isNotEmpty) {
      return direct.trim();
    }
    const nextStyle = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_ANON_KEY');
    if (nextStyle.trim().isNotEmpty) {
      return nextStyle.trim();
    }
    return null;
  }
}
