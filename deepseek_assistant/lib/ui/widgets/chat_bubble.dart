import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/chat_message.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../core/utils/text_to_speech.dart';
import 'markdown_renderer.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isStreaming;
  final VoidCallback? onRegenerate;
  final VoidCallback? onCopy;

  const ChatBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.onRegenerate,
    this.onCopy,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  bool _thinkingExpanded = false;
  bool _isSpeaking = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (_isSpeaking) {
      TextToSpeechService.instance.stop();
    }
    super.dispose();
  }

  void _toggleThinking() {
    setState(() {
      _thinkingExpanded = !_thinkingExpanded;
    });
    if (_thinkingExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = widget.message.role == 'user';
    final reasoningContent = widget.message.reasoningContent;
    final showThinking = widget.message.shouldShowThinking &&
        reasoningContent != null && reasoningContent.isNotEmpty;

    if (isUser) {
      return _buildUserBubble(theme);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAiAvatar(theme),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showThinking) _buildThinkingSection(theme),
                if (widget.message.content.isNotEmpty ||
                    (showThinking && !widget.isStreaming))
                  MarkdownRenderer(
                    content: widget.message.content,
                    isStreaming: widget.isStreaming,
                  ),
                final imageBase64List = widget.message.imageBase64List;
                if (imageBase64List != null && imageBase64List.isNotEmpty)
                  ...imageBase64List.map((base64) {
                    final bytes = ImageCacheManager.getImage(base64);
                    if (bytes == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          bytes,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                    );
                  }),
                final generatedImageUrls = widget.message.generatedImageUrls;
                if (generatedImageUrls != null && generatedImageUrls.isNotEmpty)
                  ...generatedImageUrls.map((url) =>
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 256,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )),
                if (!widget.isStreaming &&
                    widget.message.content.isNotEmpty)
                  _buildActionButtons(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.message.content,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  if (widget.message.imageBase64List != null &&
                      widget.message.imageBase64List!.isNotEmpty)
                    ...widget.message.imageBase64List!.map((base64) {
                      final bytes = ImageCacheManager.getImage(base64);
                      if (bytes == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            bytes,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAvatar(ThemeData theme) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.auto_awesome,
        size: 16,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    final iconColor = theme.colorScheme.onSurfaceVariant.withAlpha(128);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          _ToolbarButton(
            icon: Icons.copy,
            tooltip: '复制',
            iconColor: iconColor,
            onTap: () {
              Clipboard.setData(
                  ClipboardData(text: widget.message.content));
              widget.onCopy?.call();
            },
          ),
          _ToolbarButton(
            icon: _isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
            tooltip: _isSpeaking ? '停止播放' : '语音播放',
            iconColor: _isSpeaking ? theme.colorScheme.primary : iconColor,
            onTap: () async {
              if (_isSpeaking) {
                await TextToSpeechService.instance.stop();
                setState(() => _isSpeaking = false);
              } else {
                setState(() => _isSpeaking = true);
                TextToSpeechService.instance.setOnComplete(() {
                  if (mounted) setState(() => _isSpeaking = false);
                });
                await TextToSpeechService.instance.speak(widget.message.content);
              }
            },
          ),
          _ToolbarButton(
            icon: Icons.refresh,
            tooltip: '重新生成',
            iconColor: iconColor,
            onTap: widget.onRegenerate,
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleThinking,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isStreaming ? '思考中...' : '思考过程',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _thinkingExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant
                          .withAlpha(128),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _fadeAnimation,
          axisAlignment: -1.0,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                reasoningContent,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color iconColor;
  final VoidCallback? onTap;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: iconColor),
        ),
      ),
    );
  }
}
