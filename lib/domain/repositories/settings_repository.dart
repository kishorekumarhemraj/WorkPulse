abstract class SettingsRepository {
  Future<String?> getSetting(String key);
  Future<void> setSetting(String key, String value);
  Future<void> removeSetting(String key);
  Future<Map<String, String>> getAllSettings();
}
