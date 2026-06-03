import '../../core/models/chat_message.dart';
import '../storage/local_storage_service.dart';

class ChatRepository {
  final LocalStorageService _storage;

  ChatRepository(this._storage);

  // ==================== Conversations ====================

  Future<List<Conversation>> getConversations() async {
    final list = await _storage.loadConversations();
    return list.map((json) => Conversation.fromJson(json)).toList();
  }

  Future<Conversation> createConversation({String title = '新对话'}) async {
    final json = await _storage.createConversation(title);
    return Conversation.fromJson(json);
  }

  Future<void> updateConversationTitle(String id, String title) async {
    await _storage.updateConversationTitle(id, title);
  }

  Future<void> deleteConversation(String id) async {
    await _storage.deleteConversation(id);
  }

  // ==================== Messages ====================

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final list = await _storage.loadMessages(conversationId);
    return list.map((json) => _chatMessageFromJson(json)).toList();
  }

  Future<void> saveMessage({
    required String conversationId,
    required ChatMessage chatMessage,
  }) async {
    final json = _chatMessageToJson(chatMessage);
    json['conversationId'] = conversationId;
    await _storage.addMessage(conversationId, json);
    await _storage.updateConversationTime(conversationId);
  }

  Future<void> updateMessageContent(
      String conversationId, String messageId, String newContent) async {
    await _storage.updateMessageContent(
        conversationId, messageId, newContent);
  }

  Future<void> clearAllData() async {
    await _storage.clearAllData();
  }

  // ==================== Helpers ====================

  Map<String, dynamic> _chatMessageToJson(ChatMessage msg) {
    return {
      'id': msg.id,
      'role': msg.role,
      'content': msg.content,
      if (msg.reasoningContent != null && msg.reasoningContent!.isNotEmpty)
        'reasoningContent': msg.reasoningContent,
      if (msg.toolCallId != null) 'toolCallId': msg.toolCallId,
      if (msg.generatedImageUrls != null && msg.generatedImageUrls!.isNotEmpty)
        'generatedImageUrls': msg.generatedImageUrls,
      'shouldShowThinking': msg.shouldShowThinking,
      'webSearchEnabled': msg.webSearchEnabled,
      'timestamp': msg.timestamp.toIso8601String(),
    };
  }

  ChatMessage _chatMessageFromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      reasoningContent: json['reasoningContent'] as String?,
      toolCallId: json['toolCallId'] as String?,
      generatedImageUrls: json['generatedImageUrls'] != null
          ? (json['generatedImageUrls'] as List).cast<String>()
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      shouldShowThinking: json['shouldShowThinking'] as bool? ?? false,
      webSearchEnabled: json['webSearchEnabled'] as bool? ?? false,
    );
  }
}

class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '新对话',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }
}
