class ChatMessage {
  final String id;
  final String role;
  final String content;
  final String? reasoningContent;
  final List<String>? imageBase64List;
  final List<ToolCall>? toolCalls;
  final String? toolCallId;
  final String? name;
  final DateTime timestamp;
  final List<String>? generatedImageUrls;
  final bool shouldShowThinking;
  final bool webSearchEnabled;

  bool get hasGeneratedImages =>
      generatedImageUrls != null && generatedImageUrls!.isNotEmpty;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.reasoningContent,
    this.imageBase64List,
    this.toolCalls,
    this.toolCallId,
    this.name,
    required this.timestamp,
    this.generatedImageUrls,
    this.shouldShowThinking = false,
    this.webSearchEnabled = false,
  });

  Map<String, dynamic> toApiFormat() {
    if (role == 'tool') {
      return {
        'role': 'tool',
        'tool_call_id': toolCallId,
        'content': content,
      };
    }

    if (role == 'assistant' && toolCalls != null && toolCalls!.isNotEmpty) {
      return {
        'role': 'assistant',
        'content': content.isEmpty ? null : content,
        if (reasoningContent != null && reasoningContent!.isNotEmpty)
          'reasoning_content': reasoningContent,
        'tool_calls': toolCalls!.map((tc) => tc.toApiFormat()).toList(),
      };
    }

    if (role == 'user' && imageBase64List != null && imageBase64List!.isNotEmpty) {
      final contentParts = <Map<String, dynamic>>[];
      if (content.isNotEmpty) {
        contentParts.add({'type': 'text', 'text': content});
      }
      for (final base64 in imageBase64List!) {
        contentParts.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/jpeg;base64,$base64',
          },
        });
      }
      return {
        'role': 'user',
        'content': contentParts,
      };
    }

    return {
      'role': role,
      'content': content,
      if (role == 'assistant' && reasoningContent != null && reasoningContent!.isNotEmpty)
        'reasoning_content': reasoningContent,
    };
  }
}

class ToolCall {
  final String id;
  final String type;
  final FunctionCall function;

  ToolCall({required this.id, this.type = 'function', required this.function});

  Map<String, dynamic> toApiFormat() {
    return {
      'id': id,
      'type': type,
      'function': {
        'name': function.name,
        'arguments': function.arguments,
      },
    };
  }

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      id: json['id'] ?? '',
      type: json['type'] ?? 'function',
      function: FunctionCall.fromJson(json['function'] ?? {}),
    );
  }
}

class FunctionCall {
  final String name;
  final String arguments;

  FunctionCall({required this.name, required this.arguments});

  factory FunctionCall.fromJson(Map<String, dynamic> json) {
    return FunctionCall(
      name: json['name'] ?? '',
      arguments: json['arguments'] ?? '',
    );
  }
}
