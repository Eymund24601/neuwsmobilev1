import '../settings_repository.dart';

class MockSettingsRepository implements SettingsRepository {
  AppSettings _settings = const AppSettings(
    readingLanguage: 'English',
    readingTopLanguage: 'en',
    readingBottomLanguage: 'sv',
    notificationsEnabled: true,
    offlineModeEnabled: false,
  );

  @override
  Future<AppSettings> getSettings() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _settings;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _settings = settings;
  }
}
