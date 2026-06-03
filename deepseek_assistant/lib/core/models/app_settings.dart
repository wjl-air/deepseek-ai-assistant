enum ThinkingMode {
  quick,
  deep,
  custom,
}

class AppSettings {
  String weatherApiKey;
  String apiKey;
  String bochaApiKey;
  String model;
  double temperature;
  int maxTokens;
  bool isDarkMode;
  bool showThinking;
  ThinkingMode thinkingMode;
  bool thinkingExpandedByDefault;
  bool deepThinkingEnabled;
  bool webSearchEnabled;
  String language;

  AppSettings({
    this.weatherApiKey = '',
    this.apiKey = '',
    this.bochaApiKey = '',
    this.model = 'mimo-v2.5-pro',
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.isDarkMode = false,
    this.showThinking = true,
    this.thinkingMode = ThinkingMode.deep,
    this.thinkingExpandedByDefault = true,
    this.deepThinkingEnabled = false,
    this.webSearchEnabled = false,
    this.language = 'zh_CN',
  });

  AppSettings copyWith({
    String? weatherApiKey,
    String? apiKey,
    String? bochaApiKey,
    String? model,
    double? temperature,
    int? maxTokens,
    bool? isDarkMode,
    bool? showThinking,
    ThinkingMode? thinkingMode,
    bool? thinkingExpandedByDefault,
    bool? deepThinkingEnabled,
    bool? webSearchEnabled,
    String? language,
  }) {
    return AppSettings(
      weatherApiKey: weatherApiKey ?? this.weatherApiKey,
      apiKey: apiKey ?? this.apiKey,
      bochaApiKey: bochaApiKey ?? this.bochaApiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      showThinking: showThinking ?? this.showThinking,
      thinkingMode: thinkingMode ?? this.thinkingMode,
      thinkingExpandedByDefault: thinkingExpandedByDefault ?? this.thinkingExpandedByDefault,
      deepThinkingEnabled: deepThinkingEnabled ?? this.deepThinkingEnabled,
      webSearchEnabled: webSearchEnabled ?? this.webSearchEnabled,
      language: language ?? this.language,
    );
  }
}
