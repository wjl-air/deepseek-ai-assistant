import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (localizations != null) {
      return localizations;
    }
    return AppLocalizations(const Locale('zh', 'CN'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static Map<String, Map<String, String>> _localizedValues = {};

  static Future<void> load() async {
    AppLocalizations.locales.forEach((localeCode, values) {
      _localizedValues[localeCode] = values;
    });
  }

  static const Map<String, Map<String, String>> locales = {
    'zh_CN': zhCN,
    'en_US': enUS,
    'ja_JP': jaJP,
    'ko_KR': koKR,
  };

  String translate(String key) {
    final localeCode = '${locale.languageCode}_${locale.countryCode}';
    final localeCodeFallback = locale.languageCode;
    if (_localizedValues.containsKey(localeCode) && _localizedValues[localeCode]!.containsKey(key)) {
      return _localizedValues[localeCode]![key]!;
    } else if (_localizedValues.containsKey(localeCodeFallback) && _localizedValues[localeCodeFallback]!.containsKey(key)) {
      return _localizedValues[localeCodeFallback]![key]!;
    }
    return key;
  }

  String get appTitle => translate('appTitle');
  String get aiAssistant => translate('aiAssistant');
  String get conversationHistory => translate('conversationHistory');
  String get createNewConversation => translate('createNewConversation');
  String get noConversations => translate('noConversations');
  String get chatInProgress => translate('chatInProgress');
  String get settings => translate('settings');
  String get inputMessage => translate('inputMessage');
  String get imageProcessFailed => translate('imageProcessFailed');
  String get voiceRecognitionUnavailable => translate('voiceRecognitionUnavailable');
  String get deepThinking => translate('deepThinking');
  String get webSearch => translate('webSearch');
  String get copiedToClipboard => translate('copiedToClipboard');
  String get imageSelectedSend => translate('imageSelectedSend');
  String get deleteConversation => translate('deleteConversation');
  String get confirmDeleteConversation => translate('confirmDeleteConversation');
  String get cancel => translate('cancel');
  String get delete => translate('delete');
  String get renameConversation => translate('renameConversation');
  String get inputNewName => translate('inputNewName');
  String get confirm => translate('confirm');
  String get justNow => translate('justNow');
  String get minutesAgo => translate('minutesAgo');
  String get hoursAgo => translate('hoursAgo');
  String get daysAgo => translate('daysAgo');
  String get quickCalcQuestion => translate('quickCalcQuestion');
  String get quickWeatherQuestion => translate('quickWeatherQuestion');
  String get quickTranslateQuestion => translate('quickTranslateQuestion');
  String get quickUnitConvertQuestion => translate('quickUnitConvertQuestion');
  String get model => translate('model');
  String get deepThinkingSection => translate('deepThinkingSection');
  String get showThinkingProcess => translate('showThinkingProcess');
  String get showThinkingDescription => translate('showThinkingDescription');
  String get thinkingMode => translate('thinkingMode');
  String get quickThinking => translate('quickThinking');
  String get quickThinkingDescription => translate('quickThinkingDescription');
  String get deepThinkingMode => translate('deepThinkingMode');
  String get deepThinkingDescription => translate('deepThinkingDescription');
  String get customThinking => translate('customThinking');
  String get customThinkingDescription => translate('customThinkingDescription');
  String get defaultExpanded => translate('defaultExpanded');
  String get defaultExpandedDescription => translate('defaultExpandedDescription');
  String get modelParams => translate('modelParams');
  String get temperature => translate('temperature');
  String get rigorous => translate('rigorous');
  String get creative => translate('creative');
  String get maxTokens => translate('maxTokens');
  String get appearance => translate('appearance');
  String get darkMode => translate('darkMode');
  String get darkModeDescription => translate('darkModeDescription');
  String get dataManagement => translate('dataManagement');
  String get clearCache => translate('clearCache');
  String get clearCacheDescription => translate('clearCacheDescription');
  String get confirmClearCache => translate('confirmClearCache');
  String get confirmClearCacheDescription => translate('confirmClearCacheDescription');
  String get cacheCleared => translate('cacheCleared');
  String get about => translate('about');
  String get version => translate('version');
  String get aiModel => translate('aiModel');
  String get techStack => translate('techStack');
  String get descriptionImage => translate('descriptionImage');
  String get pleaseConfigureApiKey => translate('pleaseConfigureApiKey');
  String get webSearchFailed => translate('webSearchFailed');
  String get searchParseFailed => translate('searchParseFailed');
  String get toolExecutionFailed => translate('toolExecutionFailed');
  String get networkRequestFailed => translate('networkRequestFailed');
  String get language => translate('language');
  String get chineseSimplified => translate('chineseSimplified');
  String get english => translate('english');
  String get japanese => translate('japanese');
  String get korean => translate('korean');
  String get helloDeepSeekAssistant => translate('helloDeepSeekAssistant');
  String get assistantDescription => translate('assistantDescription');
  String get apiKey => translate('apiKey');
  String get apiKeyDescription => translate('apiKeyDescription');
  String get apiKeyHint => translate('apiKeyHint');
  String get bochaApiKey => translate('bochaApiKey');
  String get bochaApiKeyDescription => translate('bochaApiKeyDescription');
  String get bochaApiKeyHint => translate('bochaApiKeyHint');
  String get weatherApiKey => translate('weatherApiKey');
  String get weatherApiKeyDescription => translate('weatherApiKeyDescription');
  String get weatherApiKeyHint => translate('weatherApiKeyHint');
  String get logout => translate('logout');
  String get confirmLogout => translate('confirmLogout');
  String get loginCode => translate('loginCode');
  String get generateLoginCode => translate('generateLoginCode');
  String get loginCodeDescription => translate('loginCodeDescription');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en', 'ja', 'ko'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    await AppLocalizations.load();
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const Map<String, String> zhCN = {
  'appTitle': 'DeepSeek 助手',
  'aiAssistant': 'AI 助手',
  'conversationHistory': '对话历史',
  'createNewConversation': '创建新对话',
  'noConversations': '暂无对话记录',
  'chatInProgress': '对话中...',
  'settings': '设置',
  'inputMessage': '输入消息...',
  'imageProcessFailed': '图片处理失败，请重试',
  'voiceRecognitionUnavailable': '语音识别不可用',
  'deepThinking': '深度思考',
  'webSearch': '联网搜索',
  'copiedToClipboard': '已复制到剪贴板',
  'imageSelectedSend': '已选择图片，点击发送',
  'deleteConversation': '删除对话',
  'confirmDeleteConversation': '确定要删除这条对话吗？',
  'cancel': '取消',
  'delete': '删除',
  'renameConversation': '重命名对话',
  'inputNewName': '输入新名称',
  'confirm': '确认',
  'justNow': '刚刚',
  'minutesAgo': ' 分钟前',
  'hoursAgo': ' 小时前',
  'daysAgo': ' 天前',
  'quickCalcQuestion': '1+2*3 等于多少？',
  'quickWeatherQuestion': '今天杭州天气怎么样？',
  'quickTranslateQuestion': '翻译 "Hello World" 为中文',
  'quickUnitConvertQuestion': '100 英里等于多少公里？',
  'model': '模型',
  'deepThinkingSection': '深度思考',
  'showThinkingProcess': '显示思考过程',
  'showThinkingDescription': '展示 AI 的推理和思考过程',
  'thinkingMode': '思考模式',
  'quickThinking': '快速思考',
  'quickThinkingDescription': '简洁思考，快速回复',
  'deepThinkingMode': '深度思考',
  'deepThinkingDescription': '详细分析，逐步推理',
  'customThinking': '自定义',
  'customThinkingDescription': '使用默认设置',
  'defaultExpanded': '默认展开',
  'defaultExpandedDescription': '思考过程默认显示展开状态',
  'modelParams': '模型参数',
  'temperature': 'Temperature',
  'rigorous': '严谨',
  'creative': '创意',
  'maxTokens': 'Max Tokens',
  'appearance': '外观',
  'darkMode': '深色模式',
  'darkModeDescription': '切换深色/浅色主题',
  'dataManagement': '数据管理',
  'clearCache': '清除缓存',
  'clearCacheDescription': '删除所有对话历史和缓存数据',
  'confirmClearCache': '确认清除',
  'confirmClearCacheDescription': '确定要清除所有对话历史和缓存数据吗？此操作不可恢复。',
  'cacheCleared': '缓存已清除',
  'about': '关于',
  'version': '版本',
  'aiModel': 'AI 模型',
  'techStack': '技术栈',
  'descriptionImage': '请描述这张图片',
  'pleaseConfigureApiKey': '请先在设置中配置 API Key',
  'webSearchFailed': '搜索请求失败',
  'searchParseFailed': '搜索解析失败',
  'toolExecutionFailed': '工具执行失败',
  'networkRequestFailed': '网络请求失败',
  'language': '语言',
  'chineseSimplified': '简体中文',
  'english': 'English',
  'japanese': '日本語',
  'korean': '한국어',
  'helloDeepSeekAssistant': '你好，我是 DeepSeek 助手',
  'assistantDescription': '我可以帮你回答问题、分析图片、翻译、计算等',
  'apiKey': 'API Key',
  'apiKeyDescription': '请输入您的 API Key',
  'apiKeyHint': '输入您的 API Key',
  'bochaApiKey': '博查 API Key',
  'bochaApiKeyDescription': '请输入您的博查 API Key（用于联网搜索）',
  'bochaApiKeyHint': '输入您的博查 API Key',
  'weatherApiKey': '天气 API Key',
  'weatherApiKeyDescription': '请输入您的 OpenWeatherMap API Key（用于天气查询）',
  'weatherApiKeyHint': '输入您的天气 API Key',
  'logout': '退出登录',
  'confirmLogout': '确定要退出登录吗？',
  'loginCode': '登录码',
  'generateLoginCode': '生成登录码',
  'loginCodeDescription': '使用登录码可以在其他设备上快速登录，无需输入密码。登录码有效期5分钟，使用后立即失效。',
};

const Map<String, String> enUS = {
  'appTitle': 'DeepSeek Assistant',
  'aiAssistant': 'AI Assistant',
  'conversationHistory': 'Conversation History',
  'createNewConversation': 'Create New Chat',
  'noConversations': 'No conversations yet',
  'chatInProgress': 'Chatting...',
  'settings': 'Settings',
  'inputMessage': 'Type a message...',
  'imageProcessFailed': 'Image processing failed, please try again',
  'voiceRecognitionUnavailable': 'Voice recognition unavailable',
  'deepThinking': 'Deep Thinking',
  'webSearch': 'Web Search',
  'copiedToClipboard': 'Copied to clipboard',
  'imageSelectedSend': 'Image selected, tap to send',
  'deleteConversation': 'Delete Conversation',
  'confirmDeleteConversation': 'Are you sure you want to delete this conversation?',
  'cancel': 'Cancel',
  'delete': 'Delete',
  'renameConversation': 'Rename Conversation',
  'inputNewName': 'Enter new name',
  'confirm': 'Confirm',
  'justNow': 'Just now',
  'minutesAgo': ' minutes ago',
  'hoursAgo': ' hours ago',
  'daysAgo': ' days ago',
  'quickCalcQuestion': 'What is 1+2*3?',
  'quickWeatherQuestion': "What's the weather in Hangzhou today?",
  'quickTranslateQuestion': 'Translate "Hello World" to Chinese',
  'quickUnitConvertQuestion': 'How many kilometers in 100 miles?',
  'model': 'Model',
  'deepThinkingSection': 'Deep Thinking',
  'showThinkingProcess': 'Show Thinking Process',
  'showThinkingDescription': 'Display AI reasoning and thinking process',
  'thinkingMode': 'Thinking Mode',
  'quickThinking': 'Quick Thinking',
  'quickThinkingDescription': 'Concise thinking, fast response',
  'deepThinkingMode': 'Deep Thinking',
  'deepThinkingDescription': 'Detailed analysis, step-by-step reasoning',
  'customThinking': 'Custom',
  'customThinkingDescription': 'Use default settings',
  'defaultExpanded': 'Default Expanded',
  'defaultExpandedDescription': 'Thinking process is expanded by default',
  'modelParams': 'Model Parameters',
  'temperature': 'Temperature',
  'rigorous': 'Rigorous',
  'creative': 'Creative',
  'maxTokens': 'Max Tokens',
  'appearance': 'Appearance',
  'darkMode': 'Dark Mode',
  'darkModeDescription': 'Toggle dark/light theme',
  'dataManagement': 'Data Management',
  'clearCache': 'Clear Cache',
  'clearCacheDescription': 'Delete all chat history and cached data',
  'confirmClearCache': 'Confirm Clear',
  'confirmClearCacheDescription': 'Are you sure you want to clear all chat history and cached data? This action cannot be undone.',
  'cacheCleared': 'Cache cleared',
  'about': 'About',
  'version': 'Version',
  'aiModel': 'AI Model',
  'techStack': 'Tech Stack',
  'descriptionImage': 'Please describe this image',
  'pleaseConfigureApiKey': 'Please configure API Key in settings first',
  'webSearchFailed': 'Search request failed',
  'searchParseFailed': 'Search parsing failed',
  'toolExecutionFailed': 'Tool execution failed',
  'networkRequestFailed': 'Network request failed',
  'language': 'Language',
  'chineseSimplified': '简体中文',
  'english': 'English',
  'japanese': '日本語',
  'korean': '한국어',
  'helloDeepSeekAssistant': 'Hello, I am DeepSeek Assistant',
  'assistantDescription': 'I can help you answer questions, analyze images, translate, calculate, and more',
  'apiKey': 'API Key',
  'apiKeyDescription': 'Please enter your API Key',
  'apiKeyHint': 'Enter your API Key',
  'bochaApiKey': 'Bocha API Key',
  'bochaApiKeyDescription': 'Please enter your Bocha API Key (for web search)',
  'bochaApiKeyHint': 'Enter your Bocha API Key',
  'weatherApiKey': 'Weather API Key',
  'weatherApiKeyDescription': 'Please enter your OpenWeatherMap API Key (for weather queries)',
  'weatherApiKeyHint': 'Enter your weather API Key',
  'logout': 'Logout',
  'confirmLogout': 'Are you sure you want to logout?',
  'loginCode': 'Login Code',
  'generateLoginCode': 'Generate Login Code',
  'loginCodeDescription': 'Use login code to quickly login on other devices without password. Valid for 5 minutes, expires after use.',
};

const Map<String, String> jaJP = {
  'appTitle': 'DeepSeek アシスタント',
  'aiAssistant': 'AI アシスタント',
  'conversationHistory': '会話履歴',
  'createNewConversation': '新規チャット',
  'noConversations': 'まだ会話がありません',
  'chatInProgress': 'チャット中...',
  'settings': '設定',
  'inputMessage': 'メッセージを入力...',
  'imageProcessFailed': '画像の処理に失敗しました。もう一度お試しください',
  'voiceRecognitionUnavailable': '音声認識は利用できません',
  'deepThinking': '深い思考',
  'webSearch': 'ウェブ検索',
  'copiedToClipboard': 'クリップボードにコピーしました',
  'imageSelectedSend': '画像を選択しました。送信するにはタップしてください',
  'deleteConversation': '会話を削除',
  'confirmDeleteConversation': 'この会話を削除してもよろしいですか？',
  'cancel': 'キャンセル',
  'delete': '削除',
  'renameConversation': '会話名を変更',
  'inputNewName': '新しい名前を入力してください',
  'confirm': '確認',
  'justNow': 'たった今',
  'minutesAgo': ' 分前',
  'hoursAgo': ' 時間前',
  'daysAgo': ' 日前',
  'quickCalcQuestion': '1+2*3は？',
  'quickWeatherQuestion': '今日の杭州の天気は？',
  'quickTranslateQuestion': '"Hello World"を中国語に翻訳',
  'quickUnitConvertQuestion': '100マイルは何キロメートル？',
  'model': 'モデル',
  'deepThinkingSection': '深い思考',
  'showThinkingProcess': '思考プロセスを表示',
  'showThinkingDescription': 'AIの推論と思考プロセスを表示',
  'thinkingMode': '思考モード',
  'quickThinking': 'クイック思考',
  'quickThinkingDescription': '簡潔な思考、迅速な応答',
  'deepThinkingMode': '深い思考',
  'deepThinkingDescription': '詳細な分析、段階的な推論',
  'customThinking': 'カスタム',
  'customThinkingDescription': 'デフォルト設定を使用',
  'defaultExpanded': 'デフォルトで展開',
  'defaultExpandedDescription': '思考プロセスはデフォルトで展開されます',
  'modelParams': 'モデルパラメータ',
  'temperature': 'Temperature',
  'rigorous': '厳密',
  'creative': 'クリエイティブ',
  'maxTokens': 'Max Tokens',
  'appearance': '外観',
  'darkMode': 'ダークモード',
  'darkModeDescription': 'ダーク/ライトテーマを切り替え',
  'dataManagement': 'データ管理',
  'clearCache': 'キャッシュをクリア',
  'clearCacheDescription': 'すべてのチャット履歴とキャッシュデータを削除',
  'confirmClearCache': 'クリアを確認',
  'confirmClearCacheDescription': 'すべてのチャット履歴とキャッシュデータをクリアしてもよろしいですか？この操作は元に戻せません。',
  'cacheCleared': 'キャッシュがクリアされました',
  'about': 'について',
  'version': 'バージョン',
  'aiModel': 'AIモデル',
  'techStack': 'テックスタック',
  'descriptionImage': 'この画像を説明してください',
  'pleaseConfigureApiKey': 'まず設定でAPI Keyを設定してください',
  'webSearchFailed': '検索リクエストが失敗しました',
  'searchParseFailed': '検索解析が失敗しました',
  'toolExecutionFailed': 'ツールの実行が失敗しました',
  'networkRequestFailed': 'ネットワークリクエストが失敗しました',
  'language': '言語',
  'chineseSimplified': '简体中文',
  'english': 'English',
  'japanese': '日本語',
  'korean': '한국어',
  'helloDeepSeekAssistant': 'こんにちは、DeepSeek アシスタントです',
  'assistantDescription': '質問に答えたり、画像を分析したり、翻訳、計算などのお手伝いをします',
  'apiKey': 'API Key',
  'apiKeyDescription': 'API Key を入力してください',
  'apiKeyHint': 'API Key を入力',
  'bochaApiKey': 'ボーチャ API Key',
  'bochaApiKeyDescription': 'ボーチャ API Key を入力してください（ウェブ検索用）',
  'bochaApiKeyHint': 'ボーチャ API Key を入力',
  'weatherApiKey': '天気 API Key',
  'weatherApiKeyDescription': 'OpenWeatherMap API Key を入力してください（天気検索用）',
  'weatherApiKeyHint': '天気 API Key を入力',
  'logout': 'ログアウト',
  'confirmLogout': 'ログアウトしてもよろしいですか？',
  'loginCode': 'ログインコード',
  'generateLoginCode': 'ログインコードを生成',
  'loginCodeDescription': 'ログインコードを使用して、パスワードなしで他のデバイスに迅速にログインできます。有効期限は5分間で、使用後は無効になります。',
};

const Map<String, String> koKR = {
  'appTitle': 'DeepSeek 어시스턴트',
  'aiAssistant': 'AI 어시스턴트',
  'conversationHistory': '대화 기록',
  'createNewConversation': '새 대화 만들기',
  'noConversations': '아직 대화가 없습니다',
  'chatInProgress': '대화 중...',
  'settings': '설정',
  'inputMessage': '메시지 입력...',
  'imageProcessFailed': '이미지 처리에 실패했습니다. 다시 시도해 주세요',
  'voiceRecognitionUnavailable': '음성 인식을 사용할 수 없습니다',
  'deepThinking': '깊은 생각',
  'webSearch': '웹 검색',
  'copiedToClipboard': '클립보드에 복사됨',
  'imageSelectedSend': '이미지가 선택되었습니다. 전송하려면 탭하세요',
  'deleteConversation': '대화 삭제',
  'confirmDeleteConversation': '이 대화를 삭제하시겠습니까?',
  'cancel': '취소',
  'delete': '삭제',
  'renameConversation': '대화 이름 변경',
  'inputNewName': '새 이름 입력',
  'confirm': '확인',
  'justNow': '방금',
  'minutesAgo': ' 분 전',
  'hoursAgo': ' 시간 전',
  'daysAgo': ' 일 전',
  'quickCalcQuestion': '1+2*3은 얼마인가요?',
  'quickWeatherQuestion': '오늘 항저우 날씨는 어떻습니까?',
  'quickTranslateQuestion': '"Hello World"를 중국어로 번역',
  'quickUnitConvertQuestion': '100마일은 몇 킬로미터인가요?',
  'model': '모델',
  'deepThinkingSection': '깊은 생각',
  'showThinkingProcess': '생각 과정 표시',
  'showThinkingDescription': 'AI 추론과 생각 과정을 표시합니다',
  'thinkingMode': '생각 모드',
  'quickThinking': '빠른 생각',
  'quickThinkingDescription': '간결한 생각, 빠른 응답',
  'deepThinkingMode': '깊은 생각',
  'deepThinkingDescription': '상세 분석, 단계별 추론',
  'customThinking': '사용자 정의',
  'customThinkingDescription': '기본 설정 사용',
  'defaultExpanded': '기본 확장',
  'defaultExpandedDescription': '생각 과정이 기본적으로 확장됩니다',
  'modelParams': '모델 매개변수',
  'temperature': 'Temperature',
  'rigorous': '엄격',
  'creative': '창의적',
  'maxTokens': 'Max Tokens',
  'appearance': '외관',
  'darkMode': '다크 모드',
  'darkModeDescription': '다크/라이트 테마 전환',
  'dataManagement': '데이터 관리',
  'clearCache': '캐시 지우기',
  'clearCacheDescription': '모든 채팅 기록과 캐시 데이터 삭제',
  'confirmClearCache': '지우기 확인',
  'confirmClearCacheDescription': '모든 채팅 기록과 캐시 데이터를 지우시겠습니까? 이 작업은 취소할 수 없습니다.',
  'cacheCleared': '캐시가 지워졌습니다',
  'about': '정보',
  'version': '버전',
  'aiModel': 'AI 모델',
  'techStack': '기술 스택',
  'descriptionImage': '이 이미지를 설명해 주세요',
  'pleaseConfigureApiKey': '먼저 설정에서 API Key를 구성해 주세요',
  'webSearchFailed': '검색 요청 실패',
  'searchParseFailed': '검색 파싱 실패',
  'toolExecutionFailed': '도구 실행 실패',
  'networkRequestFailed': '네트워크 요청 실패',
  'language': '언어',
  'chineseSimplified': '简体中文',
  'english': 'English',
  'japanese': '日本語',
  'korean': '한국어',
  'helloDeepSeekAssistant': '안녕하세요, DeepSeek 어시스턴트입니다',
  'assistantDescription': '질문 답변, 이미지 분석, 번역, 계산 등을 도와드릴 수 있습니다',
  'apiKey': 'API Key',
  'apiKeyDescription': 'API Key를 입력해 주세요',
  'apiKeyHint': 'API Key 입력',
  'bochaApiKey': '보챠 API Key',
  'bochaApiKeyDescription': '보챠 API Key를 입력해 주세요（웹 검색용）',
  'bochaApiKeyHint': '보챠 API Key 입력',
  'weatherApiKey': '날씨 API Key',
  'weatherApiKeyDescription': 'OpenWeatherMap API Key를 입력해 주세요（날씨 조회용）',
  'weatherApiKeyHint': '날씨 API Key 입력',
  'logout': '로그아웃',
  'confirmLogout': '로그아웃 하시겠습니까?',
  'loginCode': '로그인 코드',
  'generateLoginCode': '로그인 코드 생성',
  'loginCodeDescription': '로그인 코드를 사용하면 비밀번호 없이 다른 기기에서 빠르게 로그인할 수 있습니다. 유효 기간은 5분이며, 사용 후 만료됩니다.',
};
