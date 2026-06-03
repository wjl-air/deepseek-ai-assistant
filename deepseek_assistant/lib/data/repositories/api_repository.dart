import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/models/chat_message.dart';
import '../../providers/auth_provider.dart';

class ApiRepository {
  final Dio _dio;

  ApiRepository(Ref ref) : _dio = ref.read(authProvider.notifier).dio;

  Future<List<Map<String, dynamic>>> getSessions() async {
    try {
      final response = await _dio.get('/sessions');
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> createSession({String title = '新对话'}) async {
    try {
      final response = await _dio.post('/sessions', data: {
        'title': title,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateSessionTitle(int sessionId, String title) async {
    try {
      await _dio.put('/sessions/$sessionId', data: {
        'title': title,
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> deleteSession(int sessionId) async {
    try {
      await _dio.delete('/sessions/$sessionId');
    } catch (e) {
      // ignore
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(int sessionId) async {
    try {
      final response = await _dio.get('/sessions/$sessionId/messages');
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> createMessage(
      int sessionId, Map<String, dynamic> message) async {
    try {
      final response = await _dio.post('/sessions/$sessionId/messages', data: {
        'role': message['role'],
        'content': message['content'],
        'reasoning_content': message['reasoningContent'],
        'web_search_enabled': message['webSearchEnabled'] ?? false,
        'image_urls': message['imageUrls'],
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (kDebugMode) {
        developer.log('Failed to create message: ${e.response?.statusCode} - ${e.response?.data}', name: 'ApiRepository');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        developer.log('Unexpected error creating message: $e', name: 'ApiRepository');
      }
      return null;
    }
  }

  Future<void> deleteMessage(int sessionId, int messageId) async {
    try {
      await _dio.delete('/sessions/$sessionId/messages/$messageId');
    } catch (e) {
      // ignore
    }
  }
}

class ApiConversation {
  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApiConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  String get idString => id.toString();

  factory ApiConversation.fromJson(Map<String, dynamic> json) {
    return ApiConversation(
      id: json['id'] as int,
      title: json['title'] as String? ?? '新对话',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }
}

class ApiMessage {
  final int id;
  final int sessionId;
  final String role;
  final String content;
  final String? reasoningContent;
  final bool webSearchEnabled;
  final DateTime createdAt;

  ApiMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.reasoningContent,
    required this.webSearchEnabled,
    required this.createdAt,
  });

  factory ApiMessage.fromJson(Map<String, dynamic> json) {
    return ApiMessage(
      id: json['id'] as int,
      sessionId: json['session_id'] as int,
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      reasoningContent: json['reasoning_content'] as String?,
      webSearchEnabled: json['web_search_enabled'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  ChatMessage toChatMessage() {
    return ChatMessage(
      id: id.toString(),
      role: role,
      content: content,
      reasoningContent: reasoningContent,
      timestamp: createdAt,
      shouldShowThinking: false,
      webSearchEnabled: webSearchEnabled,
    );
  }
}
