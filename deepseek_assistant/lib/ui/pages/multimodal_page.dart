import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/chat_provider.dart';
import '../../core/utils/image_utils.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/image_picker_sheet.dart';

class MultimodalPage extends ConsumerStatefulWidget {
  const MultimodalPage({super.key});

  @override
  ConsumerState<MultimodalPage> createState() => _MultimodalPageState();
}

class _MultimodalPageState extends ConsumerState<MultimodalPage> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedImageBase64;
  bool _isProcessing = false;

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
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
          const SnackBar(content: Text('图片处理失败，请重试')),
        );
      }
      return;
    }

    setState(() {
      _selectedImageBase64 = base64;
    });
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ImagePickerSheet(onPick: _pickImage),
    );
  }

  Future<void> _analyzeImage() async {
    if (_selectedImageBase64 == null) return;

    final question = _questionController.text.isNotEmpty
        ? _questionController.text
        : '请详细描述这张图片的内容';

    setState(() => _isProcessing = true);

    try {
      await ref.read(chatProvider.notifier).sendMessage(
        content: question,
        imageBase64List: [_selectedImageBase64!],
      );

      setState(() {
        _isProcessing = false;
        _selectedImageBase64 = null;
        _questionController.clear();
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析失败: $e')),
        );
      }
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImageBase64 = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '多模态识图',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(theme)
                : _buildResultsList(chatState),
          ),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withAlpha(127),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.image_search,
              size: 50,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '多模态识图',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '上传图片，我可以帮你：\n· 识别图片内容\n· OCR 文字提取\n· 看图问答\n· 图片描述',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _showImagePickerSheet,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('选择图片'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(ChatState chatState) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final message = chatState.messages[index];
        return ChatBubble(
          message: message,
          isStreaming: chatState.status == ChatStatus.streaming &&
              index == chatState.messages.length - 1,
          onCopy: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已复制到剪贴板')),
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          if (_selectedImageBase64 != null) _buildImagePreview(theme),
          if (_selectedImageBase64 != null) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _isProcessing ? null : _showImagePickerSheet,
                icon: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _questionController,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: '向 AI 提问这张图片...',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _analyzeImage(),
                ),
              ),
              const SizedBox(width: 4),
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                FloatingActionButton(
                  onPressed:
                      _selectedImageBase64 != null ? _analyzeImage : null,
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

  Widget _buildImagePreview(ThemeData theme) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(_selectedImageBase64!),
                  width: 100,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 100,
                    height: 120,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.image,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _clearImage,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('图片已选择', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  '输入问题或留空让 AI 自动描述',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
