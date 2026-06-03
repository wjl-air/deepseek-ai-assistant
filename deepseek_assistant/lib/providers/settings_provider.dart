import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/models/app_settings.dart';
import '../data/repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repo);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository) : super(AppSettings());

  Future<void> loadSettings() async {
    state = await _repository.loadSettings();
    if (!AppConfig.availableModels.contains(state.model)) {
      state = state.copyWith(model: AppConfig.defaultModel);
      await _repository.saveSettings(state);
    }
  }

  Future<void> updateApiKey(String apiKey) async {
    state = state.copyWith(apiKey: apiKey);
    await _repository.saveSettings(state);
  }

  Future<void> updateBochaApiKey(String apiKey) async {
    state = state.copyWith(bochaApiKey: apiKey);
    await _repository.saveSettings(state);
  }

  Future<void> updateWeatherApiKey(String apiKey) async {
    state = state.copyWith(weatherApiKey: apiKey);
    await _repository.saveSettings(state);
  }

  Future<void> updateModel(String model) async {
    state = state.copyWith(model: model);
    await _repository.saveSettings(state);
  }

  Future<void> updateTemperature(double temperature) async {
    state = state.copyWith(temperature: temperature);
    await _repository.saveSettings(state);
  }

  Future<void> updateMaxTokens(int maxTokens) async {
    state = state.copyWith(maxTokens: maxTokens);
    await _repository.saveSettings(state);
  }

  Future<void> toggleTheme(bool isDark) async {
    state = state.copyWith(isDarkMode: isDark);
    await _repository.saveSettings(state);
  }

  Future<void> updateShowThinking(bool show) async {
    state = state.copyWith(showThinking: show);
    await _repository.saveSettings(state);
  }

  Future<void> updateThinkingMode(ThinkingMode mode) async {
    state = state.copyWith(thinkingMode: mode);
    await _repository.saveSettings(state);
  }

  Future<void> updateThinkingExpanded(bool expanded) async {
    state = state.copyWith(thinkingExpandedByDefault: expanded);
    await _repository.saveSettings(state);
  }

  Future<void> toggleDeepThinking() async {
    state = state.copyWith(deepThinkingEnabled: !state.deepThinkingEnabled);
    await _repository.saveSettings(state);
  }

  Future<void> toggleWebSearch() async {
    state = state.copyWith(webSearchEnabled: !state.webSearchEnabled);
    await _repository.saveSettings(state);
  }

  Future<void> updateLanguage(String language) async {
    state = state.copyWith(language: language);
    await _repository.saveSettings(state);
  }
}
