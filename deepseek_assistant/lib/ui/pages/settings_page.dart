import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/models/app_settings.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isGeneratingCode = false;
  String? _generatedLoginCode;
  DateTime? _loginCodeExpiry;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _generateLoginCode() async {
    setState(() => _isGeneratingCode = true);
    final result = await ref.read(authProvider.notifier).generateLoginCode();
    setState(() => _isGeneratingCode = false);

    if (result != null && mounted) {
      setState(() {
        _generatedLoginCode = result['code'];
        _loginCodeExpiry = DateTime.tryParse(result['expires_at']);
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生成登录码失败')),
      );
    }
  }

  String _getThinkingModeLabel(ThinkingMode mode, AppLocalizations loc) {
    switch (mode) {
      case ThinkingMode.quick:
        return loc.quickThinking;
      case ThinkingMode.deep:
        return loc.deepThinkingMode;
      case ThinkingMode.custom:
        return loc.customThinking;
    }
  }

  String _getThinkingModeDescription(ThinkingMode mode, AppLocalizations loc) {
    switch (mode) {
      case ThinkingMode.quick:
        return loc.quickThinkingDescription;
      case ThinkingMode.deep:
        return loc.deepThinkingDescription;
      case ThinkingMode.custom:
        return loc.customThinkingDescription;
    }
  }

  String _getLanguageLabel(String language, AppLocalizations loc) {
    switch (language) {
      case 'zh_CN':
        return loc.chineseSimplified;
      case 'en_US':
        return loc.english;
      case 'ja_JP':
        return loc.japanese;
      case 'ko_KR':
        return loc.korean;
      default:
        return loc.chineseSimplified;
    }
  }

  Future<void> _clearCache() async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.confirmClearCache),
        content: Text(loc.confirmClearCacheDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final chatNotifier = ref.read(chatProvider.notifier);
      final convs = ref.read(chatProvider).conversations;
      for (final conv in convs) {
        await chatNotifier.deleteConversation(conv.idString);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.cacheCleared)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.settings, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text(loc.model, style: theme.textTheme.titleSmall),
              subtitle: Text(settings.model),
              trailing: DropdownButton<String>(
                value: settings.model,
                underline: const SizedBox(),
                items: AppConfig.availableModels
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(settingsProvider.notifier).updateModel(value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              title: Text(loc.language, style: theme.textTheme.titleSmall),
              subtitle: Text(_getLanguageLabel(settings.language, loc)),
              trailing: DropdownButton<String>(
                value: settings.language,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'zh_CN', child: Text('简体中文')),
                  DropdownMenuItem(value: 'en_US', child: Text('English')),
                  DropdownMenuItem(value: 'ja_JP', child: Text('日本語')),
                  DropdownMenuItem(value: 'ko_KR', child: Text('한국어')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(settingsProvider.notifier).updateLanguage(value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(loc.deepThinkingSection),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(loc.showThinkingProcess, style: theme.textTheme.titleSmall),
                  subtitle: Text(loc.showThinkingDescription),
                  value: settings.showThinking,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).updateShowThinking(value);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(loc.thinkingMode, style: theme.textTheme.titleSmall),
                  subtitle: Text(_getThinkingModeDescription(settings.thinkingMode, loc)),
                  trailing: DropdownButton<ThinkingMode>(
                    value: settings.thinkingMode,
                    underline: const SizedBox(),
                    items: ThinkingMode.values
                        .map((mode) => DropdownMenuItem(
                              value: mode,
                              child: Text(_getThinkingModeLabel(mode, loc)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(settingsProvider.notifier).updateThinkingMode(value);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(loc.defaultExpanded, style: theme.textTheme.titleSmall),
                  subtitle: Text(loc.defaultExpandedDescription),
                  value: settings.thinkingExpandedByDefault,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).updateThinkingExpanded(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(loc.modelParams),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.temperature,
                          style: theme.textTheme.titleSmall),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          settings.temperature.toStringAsFixed(1),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: settings.temperature,
                  min: 0.0,
                  max: 2.0,
                  divisions: 20,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .updateTemperature(value);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.rigorous, style: theme.textTheme.bodySmall),
                      Text(loc.creative, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.maxTokens,
                          style: theme.textTheme.titleSmall),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${settings.maxTokens}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: settings.maxTokens.toDouble(),
                  min: 100,
                  max: 8192,
                  divisions: 80,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .updateMaxTokens(value.round());
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(loc.appearance),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: Text(loc.darkMode, style: theme.textTheme.titleSmall),
              subtitle: Text(loc.darkModeDescription),
              value: settings.isDarkMode,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).toggleTheme(value);
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(loc.dataManagement),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.delete_outline,
                  color: theme.colorScheme.error),
              title: Text(loc.clearCache,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                  )),
              subtitle: Text(loc.clearCacheDescription),
              onTap: _clearCache,
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(loc.loginCode),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_generatedLoginCode != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '你的登录码',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            _generatedLoginCode!,
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_loginCodeExpiry != null)
                            Text(
                              '有效期至: ${_loginCodeExpiry!.toLocal().toString().substring(0, 19)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isGeneratingCode ? null : _generateLoginCode,
                      icon: _isGeneratingCode
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(Icons.key),
                      label: Text(_isGeneratingCode ? '生成中...' : loc.generateLoginCode),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.loginCodeDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(loc.about),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(title: Text(loc.version), subtitle: const Text('1.0.0')),
                const Divider(height: 1),
                ListTile(
                    title: Text(loc.aiModel),
                    subtitle: const Text('DeepSeek V4 Pro')),
                const Divider(height: 1),
                ListTile(
                    title: Text(loc.techStack),
                    subtitle: const Text('Flutter 3.24 + Riverpod 2.5 + Isar')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text(loc.logout,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                  )),
              onTap: () => _confirmLogout(),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.logout),
        content: Text(loc.confirmLogout),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.logout),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
