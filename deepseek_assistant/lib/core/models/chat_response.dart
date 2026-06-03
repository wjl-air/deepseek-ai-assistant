import 'chat_message.dart';

class ChatResponse {
  final String content;
  final String? reasoningContent;
  final String? finishReason;
  final List<ToolCall>? toolCalls;
  final int totalTokens;
  final bool isStreamDone;

  ChatResponse({
    required this.content,
    this.reasoningContent,
    this.finishReason,
    this.toolCalls,
    this.totalTokens = 0,
    this.isStreamDone = false,
  });

  String get fullContent {
    if (reasoningContent != null && reasoningContent!.isNotEmpty) {
      return '$reasoningContent\n\n$content';
    }
    return content;
  }
}
