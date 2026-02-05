import '../settings_repository.dart';

class MockSettingsRepository implements SettingsRepository {
  @override
  Future<AppSettings> getSettings() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return const AppSettings(
      readingLanguage: 'English',
      notificationsEnabled: true,
      offlineModeEnabled: false,
    );
  }
}
