import 'package:supabase_flutter/supabase_flutter.dart';

import '../settings_repository.dart';
import 'supabase_mapping_utils.dart';

class SupabaseSettingsRepository implements SettingsRepository {
  const SupabaseSettingsRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<AppSettings> getSettings() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      return const AppSettings(
        readingLanguage: 'English',
        readingTopLanguage: 'en',
        readingBottomLanguage: 'sv',
        notificationsEnabled: true,
        offlineModeEnabled: false,
      );
    }

    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('user_settings')
          .select(
            'ui_lang,reading_lang_top,reading_lang_bottom,push_notifications_enabled',
          )
          .eq('user_id', authUser.id)
          .maybeSingle();
    } on PostgrestException {
      row = null;
    }

    if (row != null) {
      final topLang = _normalizeLangCode(
        SupabaseMappingUtils.stringValue(row, const ['reading_lang_top']),
        fallback: 'en',
      );
      final bottomLang = _normalizeLangCode(
        SupabaseMappingUtils.stringValue(row, const ['reading_lang_bottom']),
        fallback: topLang == 'en' ? 'sv' : 'en',
      );
      return AppSettings(
        readingLanguage: SupabaseMappingUtils.stringValue(row, const [
          'ui_lang',
          'reading_lang_top',
        ], fallback: 'English'),
        readingTopLanguage: topLang,
        readingBottomLanguage: bottomLang,
        notificationsEnabled: SupabaseMappingUtils.boolValue(row, const [
          'push_notifications_enabled',
        ], fallback: true),
        offlineModeEnabled: false,
      );
    }

    final fallbackRow = await _client
        .from('profiles')
        .select('reading_language,notifications_enabled,offline_mode_enabled')
        .eq('id', authUser.id)
        .maybeSingle();

    if (fallbackRow == null) {
      return const AppSettings(
        readingLanguage: 'English',
        readingTopLanguage: 'en',
        readingBottomLanguage: 'sv',
        notificationsEnabled: true,
        offlineModeEnabled: false,
      );
    }

    final topLang = _normalizeLangCode(
      SupabaseMappingUtils.stringValue(fallbackRow, const ['reading_language']),
      fallback: 'en',
    );
    return AppSettings(
      readingLanguage: SupabaseMappingUtils.stringValue(fallbackRow, const [
        'reading_language',
      ], fallback: 'English'),
      readingTopLanguage: topLang,
      readingBottomLanguage: topLang == 'en' ? 'sv' : 'en',
      notificationsEnabled: SupabaseMappingUtils.boolValue(fallbackRow, const [
        'notifications_enabled',
      ], fallback: true),
      offlineModeEnabled: SupabaseMappingUtils.boolValue(fallbackRow, const [
        'offline_mode_enabled',
      ], fallback: false),
    );
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      return;
    }

    try {
      await _client.from('user_settings').upsert({
        'user_id': authUser.id,
        'ui_lang': settings.readingLanguage,
        'reading_lang_top': settings.readingTopLanguage,
        'reading_lang_bottom': settings.readingBottomLanguage,
        'push_notifications_enabled': settings.notificationsEnabled,
      });
      return;
    } on PostgrestException {
      // fall through to legacy profile settings table
    }

    await _client
        .from('profiles')
        .update({
          'reading_language': settings.readingLanguage,
          'notifications_enabled': settings.notificationsEnabled,
          'offline_mode_enabled': settings.offlineModeEnabled,
        })
        .eq('id', authUser.id);
  }

  String _normalizeLangCode(String value, {required String fallback}) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return fallback;
    }
    switch (normalized) {
      case 'english':
        return 'en';
      case 'swedish':
        return 'sv';
      case 'french':
        return 'fr';
      case 'german':
        return 'de';
      case 'spanish':
        return 'es';
      case 'italian':
        return 'it';
      case 'portuguese':
        return 'pt';
      default:
        return normalized;
    }
  }
}
