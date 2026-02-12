class AppSettings {
  const AppSettings({
    required this.readingLanguage,
    required this.readingTopLanguage,
    required this.readingBottomLanguage,
    required this.notificationsEnabled,
    required this.offlineModeEnabled,
  });

  final String readingLanguage;
  final String readingTopLanguage;
  final String readingBottomLanguage;
  final bool notificationsEnabled;
  final bool offlineModeEnabled;

  AppSettings copyWith({
    String? readingLanguage,
    String? readingTopLanguage,
    String? readingBottomLanguage,
    bool? notificationsEnabled,
    bool? offlineModeEnabled,
  }) {
    return AppSettings(
      readingLanguage: readingLanguage ?? this.readingLanguage,
      readingTopLanguage: readingTopLanguage ?? this.readingTopLanguage,
      readingBottomLanguage:
          readingBottomLanguage ?? this.readingBottomLanguage,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      offlineModeEnabled: offlineModeEnabled ?? this.offlineModeEnabled,
    );
  }
}

abstract class SettingsRepository {
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);
}
