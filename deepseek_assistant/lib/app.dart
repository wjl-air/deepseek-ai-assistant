import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'providers/settings_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/auth_provider.dart';
import 'ui/theme/app_theme.dart';
import 'ui/pages/chat_page.dart';
import 'ui/pages/login_page.dart';

class DeepSeekApp extends ConsumerStatefulWidget {
  const DeepSeekApp({super.key});

  @override
  ConsumerState<DeepSeekApp> createState() => _DeepSeekAppState();
}

class _DeepSeekAppState extends ConsumerState<DeepSeekApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initProviders();
    });
  }

  Future<void> _initProviders() async {
    await ref.read(settingsProvider.notifier).loadSettings();
    // chatProvider 现在会监听认证状态变化，不需要在这里调用 init
    setState(() => _isInitialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authProvider);

    Locale locale;
    switch (settings.language) {
      case 'en_US':
        locale = const Locale('en', 'US');
        break;
      case 'ja_JP':
        locale = const Locale('ja', 'JP');
        break;
      case 'ko_KR':
        locale = const Locale('ko', 'KR');
        break;
      default:
        locale = const Locale('zh', 'CN');
    }

    return MaterialApp(
      title: 'DeepSeek Assistant',
      debugShowCheckedModeBanner: false,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
        Locale('ja', 'JP'),
        Locale('ko', 'KR'),
      ],
      home: authState.isAuthenticated ? const ChatPage() : const LoginPage(),
    );
  }
}
