class AppSettings {
  const AppSettings({
    required this.readingLanguage,
    required this.notificationsEnabled,
    required this.offlineModeEnabled,
  });

  final String readingLanguage;
  final bool notificationsEnabled;
  final bool offlineModeEnabled;

  AppSettings copyWith({
    String? readingLanguage,
    bool? notificationsEnabled,
    bool? offlineModeEnabled,
  }) {
    return AppSettings(
      readingLanguage: readingLanguage ?? this.readingLanguage,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      offlineModeEnabled: offlineModeEnabled ?? this.offlineModeEnabled,
    );
  }
}

abstract class SettingsRepository {
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);
}
