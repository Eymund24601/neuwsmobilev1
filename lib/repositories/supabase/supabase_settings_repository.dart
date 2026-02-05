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
        notificationsEnabled: true,
        offlineModeEnabled: false,
      );
    }

    final row = await _client
        .from('profiles')
        .select('reading_language,notifications_enabled,offline_mode_enabled')
        .eq('id', authUser.id)
        .maybeSingle();

    if (row == null) {
      return const AppSettings(
        readingLanguage: 'English',
        notificationsEnabled: true,
        offlineModeEnabled: false,
      );
    }

    return AppSettings(
      readingLanguage: SupabaseMappingUtils.stringValue(row, const [
        'reading_language',
      ], fallback: 'English'),
      notificationsEnabled: SupabaseMappingUtils.boolValue(row, const [
        'notifications_enabled',
      ], fallback: true),
      offlineModeEnabled: SupabaseMappingUtils.boolValue(row, const [
        'offline_mode_enabled',
      ], fallback: false),
    );
  }
}
