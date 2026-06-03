import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/chat_provider.dart';
import '../../providers/voice_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/rag_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../core/models/chat_message.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/image_picker_sheet.dart';
import '../widgets/rag_source_indicator.dart';
import 'settings_page.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _pendingImageBase64;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final loc = AppLocalizations.of(context)!;
    final text = _textController.text.trim();
    final hasImage = _pendingImageBase64 != null;
    if (text.isEmpty && !hasImage) return;

    final imageData = hasImage ? [_pendingImageBase64!] : null;

    setState(() {
      _pendingImageBase64 = null;
    });

    _textController.clear();
    _focusNode.requestFocus();

    await ref.read(chatProvider.notifier).sendMessage(
      content: text.isNotEmpty ? text : (hasImage ? loc.descriptionImage : ''),
      imageBase64List: imageData,
    );
    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    final loc = AppLocalizations.of(context)!;
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );

    if (xFile == null) return;

    final base64 = await ImageUtils.compressAndEncode(xFile);
    if (base64 == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.imageProcessFailed)),
        );
      }
      return;
    }

    setState(() {
      _pendingImageBase64 = base64;
    });
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ImagePickerSheet(onPick: _pickImage),
    );
  }

  Future<void> _startVoiceInput() async {
    final loc = AppLocalizations.of(context)!;
    final voiceNotifier = ref.read(voiceProvider.notifier);
    final available = await voiceNotifier.initSpeech();

    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.voiceRecognitionUnavailable)),
        );
      }
      return;
    }

    await voiceNotifier.startListening();
  }

  Future<void> _stopVoiceInput() async {
    final voiceNotifier = ref.read(voiceProvider.notifier);
    await voiceNotifier.stopListening();
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  Widget _buildDrawer() {
    final loc = AppLocalizations.of(context)!;
    final chatState = ref.watch(chatProvider);
    final convs = chatState.conversations;
    final currentId = chatState.currentConversationId;

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.conversationHistory,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ref.read(chatProvider.notifier).createNewConversation();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(loc.createNewConversation),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: convs.isEmpty
                ? Center(
                    child: Text(
                      loc.noConversations,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: convs.length,
                    itemBuilder: (context, index) {
                      final conv = convs[index];
                      final isActive = conv.id == currentId;

                      return ListTile(
                        selected: isActive,
                        selectedTileColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withAlpha(60),
                        title: Text(
                          conv.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          _formatDate(conv.updatedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          onPressed: () => _confirmDelete(conv.idString),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(chatProvider.notifier)
                              .loadConversation(conv.idString);
                        },
                        onLongPress: () => _showRenameDialog(conv.idString, conv.title),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final loc = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return loc.justNow;
    if (diff.inHours < 1) return '${diff.inMinutes}${loc.minutesAgo}';
    if (diff.inDays < 1) return '${diff.inHours}${loc.hoursAgo}';
    if (diff.inDays < 7) return '${diff.inDays}${loc.daysAgo}';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDelete(String conversationId) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.deleteConversation),
        content: Text(loc.confirmDeleteConversation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(chatProvider.notifier).deleteConversation(conversationId);
    }
  }

  void _showRenameDialog(String conversationId, String currentTitle) {
    final loc = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.renameConversation),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: loc.inputNewName,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ref
                  .read(chatProvider.notifier)
                  .renameConversation(conversationId, value.trim());
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref
                    .read(chatProvider.notifier)
                    .renameConversation(conversationId, controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final chatState = ref.watch(chatProvider);
    final voiceData = ref.watch(voiceProvider);

    ref.listen(voiceProvider, (prev, next) {
      if (next.status == VoiceState.listening) {
        _textController.text = next.recognizedText;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: next.recognizedText.length),
        );
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: GestureDetector(
          onTap: _openDrawer,
          child: Text(
            chatState.currentConversationId != null
                ? loc.chatInProgress
                : loc.aiAssistant,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _openDrawer,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(context)
                : _buildMessageList(chatState),
          ),
          if (chatState.errorMessage != null)
            _buildErrorBanner(chatState.errorMessage!),
          _buildModeSwitcher(),
          _buildInputArea(voiceData),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final nickname = authState.nickname ?? '';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withAlpha(127),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            nickname.isNotEmpty ? '${loc.helloDeepSeekAssistant}, $nickname!' : loc.helloDeepSeekAssistant,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            loc.assistantDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickChip(loc.quickCalcQuestion),
              _buildQuickChip(loc.quickWeatherQuestion),
              _buildQuickChip(loc.quickTranslateQuestion),
              _buildQuickChip(loc.quickUnitConvertQuestion),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () async {
        await ref.read(chatProvider.notifier).sendMessage(content: text);
        _scrollToBottom();
      },
    );
  }

  Widget _buildMessageList(ChatState chatState) {
    final loc = AppLocalizations.of(context)!;
    final ragState = ref.watch(ragProvider);
    
    // 过滤掉 tool 消息，不显示给用户
    final displayMessages = chatState.messages.where((msg) =>
      msg.role != 'tool' &&
      !(msg.role == 'assistant' && msg.toolCalls != null && msg.toolCalls!.isNotEmpty && msg.content.isEmpty)
    ).toList();
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      cacheExtent: 1000.0,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      itemCount: displayMessages.length +
          (chatState.status == ChatStatus.streaming ||
                  chatState.status == ChatStatus.loading
              ? 1
              : 0),
      itemBuilder: (context, index) {
        if (index == displayMessages.length &&
            (chatState.status == ChatStatus.streaming ||
                chatState.status == ChatStatus.loading)) {
          return RepaintBoundary(
            child: Column(
              children: [
                if (chatState.streamingContent.isNotEmpty ||
                    chatState.streamingReasoning.isNotEmpty)
                  ChatBubble(
                    message: ChatMessage(
                      id: 'streaming',
                      role: 'assistant',
                      content: chatState.streamingContent,
                      reasoningContent: chatState.streamingReasoning.isNotEmpty
                          ? chatState.streamingReasoning
                          : null,
                      timestamp: DateTime.now(),
                      webSearchEnabled: ref.read(settingsProvider).webSearchEnabled,
                    ),
                    isStreaming: true,
                  ),
                if (ragState.status == RagStatus.searching)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: RagSearchingIndicator(
                      query: ragState.lastResult?.query ?? '',
                    ),
                  ),
                const TypingIndicator(),
              ],
            ),
          );
        }

        final message = displayMessages[index];
        // 找到原始索引中当前消息的位置，用于判断是否是最后一条
        final originalIndex = chatState.messages.indexOf(message);

        return RepaintBoundary(
          child: Column(
            children: [
              ChatBubble(
                message: message,
                onRegenerate: message.role == 'assistant' &&
                        originalIndex == chatState.messages.length - 1
                    ? () => ref.read(chatProvider.notifier).regenerateLast()
                    : null,
                onCopy: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.copiedToClipboard)),
                  );
                },
              ),
              if (message.role == 'assistant' &&
                  message.webSearchEnabled &&
                  ragState.lastResult != null &&
                  ragState.lastResult!.sources.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RagSourceIndicator(
                    sources: ragState.lastResult!.sources,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => ref.read(chatProvider.notifier).clearError(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(VoiceData voiceData) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final status = ref.watch(chatProvider).status;
    final isLoading =
        status == ChatStatus.loading || status == ChatStatus.streaming;
    final isRecording = voiceData.status == VoiceState.listening;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingImageBase64 != null) _buildPendingImagePreview(theme),
          if (_pendingImageBase64 != null) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: isLoading ? null : _showImagePickerSheet,
                icon: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: loc.inputMessage,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                onPressed: isLoading
                    ? null
                    : (isRecording ? _stopVoiceInput : _startVoiceInput),
                icon: Icon(
                  isRecording ? Icons.mic : Icons.mic_none,
                  color: isRecording
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              if (isLoading)
                FloatingActionButton(
                  onPressed: () =>
                      ref.read(chatProvider.notifier).stopGeneration(),
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                  mini: true,
                  child: const Icon(Icons.stop),
                  elevation: 0,
                )
              else
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  elevation: 0,
                  child: const Icon(Icons.arrow_upward),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingImagePreview(ThemeData theme) {
    final loc = AppLocalizations.of(context)!;
    final bytes = ImageCacheManager.getImage(_pendingImageBase64!);
    
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: bytes != null
                    ? RepaintBoundary(
                        child: Image.memory(
                          bytes,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image),
                      ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _pendingImageBase64 = null;
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.imageSelectedSend,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    final loc = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withAlpha(76),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              icon: Icons.psychology,
              label: loc.deepThinking,
              isActive: settings.deepThinkingEnabled,
              onTap: () {
                ref.read(settingsProvider.notifier).toggleDeepThinking();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ModeButton(
              icon: Icons.language,
              label: loc.webSearch,
              isActive: settings.webSearchEnabled,
              onTap: () {
                ref.read(settingsProvider.notifier).toggleWebSearch();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      color: isActive 
          ? theme.colorScheme.primaryContainer 
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.outlineVariant,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isActive 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}