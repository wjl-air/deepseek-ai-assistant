import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/app_settings.dart';

class SettingsRepository {
  static const _keyApiKey = 'settings_api_key';
  static const _keyBochaApiKey = 'settings_bocha_api_key';
  static const _keyWeatherApiKey = 'settings_weather_api_key';
  static const _keyModel = 'settings_model';
  static const _keyTemperature = 'settings_temperature';
  static const _keyMaxTokens = 'settings_max_tokens';
  static const _keyDarkMode = 'settings_dark_mode';
  static const _keyShowThinking = 'settings_show_thinking';
  static const _keyThinkingMode = 'settings_thinking_mode';
  static const _keyThinkingExpanded = 'settings_thinking_expanded';
  static const _keyDeepThinkingEnabled = 'settings_deep_thinking_enabled';
  static const _keyWebSearchEnabled = 'settings_web_search_enabled';
  static const _keyLanguage = 'settings_language';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final thinkingModeIndex = prefs.getInt(_keyThinkingMode);
    final thinkingMode = thinkingModeIndex != null && thinkingModeIndex >= 0 && thinkingModeIndex < ThinkingMode.values.length
        ? ThinkingMode.values[thinkingModeIndex]
        : ThinkingMode.deep;

    return AppSettings(
      apiKey: prefs.getString(_keyApiKey) ?? '',
      bochaApiKey: prefs.getString(_keyBochaApiKey) ?? '',
      weatherApiKey: prefs.getString(_keyWeatherApiKey) ?? '',
      model: prefs.getString(_keyModel) ?? 'mimo-v2.5-pro',
      temperature: prefs.getDouble(_keyTemperature) ?? 0.7,
      maxTokens: prefs.getInt(_keyMaxTokens) ?? 4096,
      isDarkMode: prefs.getBool(_keyDarkMode) ?? false,
      showThinking: prefs.getBool(_keyShowThinking) ?? true,
      thinkingMode: thinkingMode,
      thinkingExpandedByDefault: prefs.getBool(_keyThinkingExpanded) ?? true,
      deepThinkingEnabled: prefs.getBool(_keyDeepThinkingEnabled) ?? false,
      webSearchEnabled: prefs.getBool(_keyWebSearchEnabled) ?? false,
      language: prefs.getString(_keyLanguage) ?? 'zh_CN',
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyApiKey, settings.apiKey);
    await prefs.setString(_keyBochaApiKey, settings.bochaApiKey);
    await prefs.setString(_keyWeatherApiKey, settings.weatherApiKey);
    await prefs.setString(_keyModel, settings.model);
    await prefs.setDouble(_keyTemperature, settings.temperature);
    await prefs.setInt(_keyMaxTokens, settings.maxTokens);
    await prefs.setBool(_keyDarkMode, settings.isDarkMode);
    await prefs.setBool(_keyShowThinking, settings.showThinking);
    await prefs.setInt(_keyThinkingMode, settings.thinkingMode.index);
    await prefs.setBool(_keyThinkingExpanded, settings.thinkingExpandedByDefault);
    await prefs.setBool(_keyDeepThinkingEnabled, settings.deepThinkingEnabled);
    await prefs.setBool(_keyWebSearchEnabled, settings.webSearchEnabled);
    await prefs.setString(_keyLanguage, settings.language);
  }

  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyApiKey);
    await prefs.remove(_keyBochaApiKey);
    await prefs.remove(_keyWeatherApiKey);
    await prefs.remove(_keyModel);
    await prefs.remove(_keyTemperature);
    await prefs.remove(_keyMaxTokens);
    await prefs.remove(_keyDarkMode);
    await prefs.remove(_keyShowThinking);
    await prefs.remove(_keyThinkingMode);
    await prefs.remove(_keyThinkingExpanded);
    await prefs.remove(_keyDeepThinkingEnabled);
    await prefs.remove(_keyWebSearchEnabled);
    await prefs.remove(_keyLanguage);
  }
}
