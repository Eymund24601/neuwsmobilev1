class AppSettings {
  const AppSettings({
    required this.readingLanguage,
    required this.notificationsEnabled,
    required this.offlineModeEnabled,
  });

  final String readingLanguage;
  final bool notificationsEnabled;
  final bool offlineModeEnabled;
}

abstract class SettingsRepository {
  Future<AppSettings> getSettings();
}
