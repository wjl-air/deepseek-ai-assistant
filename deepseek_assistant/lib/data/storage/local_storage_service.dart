import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalStorageService {
  static LocalStorageService? _instance;
  final _uuid = const Uuid();

  static const _keyConversations = 'conversations';
  static const _keyMessagesPrefix = 'messages_';

  Completer<void>? _lock;

  LocalStorageService._();

  static Future<LocalStorageService> init() async {
    if (_instance != null) return _instance!;
    _instance = LocalStorageService._();
    return _instance!;
  }

  static LocalStorageService get instance {
    if (_instance == null) {
      throw StateError('LocalStorageService not initialized');
    }
    return _instance!;
  }

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  String _messagesKey(String conversationId) =>
      '$_keyMessagesPrefix$conversationId';

  Future<T> _withLock<T>(Future<T> Function() action) async {
    while (_lock != null) {
      await _lock!.future;
    }
    _lock = Completer<void>();
    try {
      return await action();
    } finally {
      _lock!.complete();
      _lock = null;
    }
  }

  // ==================== Conversations ====================

  Future<List<Map<String, dynamic>>> loadConversations() async {
    final prefs = await _prefs;
    final data = prefs.getString(_keyConversations);
    if (data == null) return [];

    try {
      final list = jsonDecode(data) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Failed to decode conversations: $e', name: 'Storage');
      return [];
    }
  }

  Future<void> _saveConversations(
      List<Map<String, dynamic>> conversations) async {
    final prefs = await _prefs;
    await prefs.setString(_keyConversations, jsonEncode(conversations));
  }

  Future<Map<String, dynamic>> createConversation(String title) {
    return _withLock(() async {
      final conversations = await loadConversations();

      final conv = {
        'id': _uuid.v4(),
        'title': title,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      conversations.insert(0, conv);
      await _saveConversations(conversations);

      return conv;
    });
  }

  Future<void> updateConversationTitle(String id, String title) {
    return _withLock(() async {
      final conversations = await loadConversations();
      for (final conv in conversations) {
        if (conv['id'] == id) {
          conv['title'] = title;
          conv['updatedAt'] = DateTime.now().toIso8601String();
          break;
        }
      }
      await _saveConversations(conversations);
    });
  }

  Future<void> updateConversationTime(String id) {
    return _withLock(() async {
      final conversations = await loadConversations();
      for (final conv in conversations) {
        if (conv['id'] == id) {
          conv['updatedAt'] = DateTime.now().toIso8601String();
          break;
        }
      }
      await _saveConversations(conversations);
    });
  }

  Future<void> deleteConversation(String id) {
    return _withLock(() async {
      final conversations = await loadConversations();
      conversations.removeWhere((c) => c['id'] == id);
      await _saveConversations(conversations);

      final prefs = await _prefs;
      await prefs.remove(_messagesKey(id));
    });
  }

  // ==================== Messages ====================

  Future<List<Map<String, dynamic>>> loadMessages(
      String conversationId) async {
    final prefs = await _prefs;
    final data = prefs.getString(_messagesKey(conversationId));
    if (data == null) return [];

    try {
      final list = jsonDecode(data) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Failed to decode messages: $e', name: 'Storage');
      return [];
    }
  }

  Future<void> _saveMessages(
      String conversationId,
      List<Map<String, dynamic>> messages) async {
    final prefs = await _prefs;
    await prefs.setString(
        _messagesKey(conversationId), jsonEncode(messages));
  }

  Future<Map<String, dynamic>> addMessage(
      String conversationId, Map<String, dynamic> message) {
    return _withLock(() async {
      final messages = await loadMessages(conversationId);

      final msg = {
        'id': _uuid.v4(),
        ...message,
        'timestamp': DateTime.now().toIso8601String(),
      };

      messages.add(msg);
      await _saveMessages(conversationId, messages);

      return msg;
    });
  }

  Future<void> updateMessageContent(
      String conversationId, String messageId, String newContent) {
    return _withLock(() async {
      final messages = await loadMessages(conversationId);
      for (final msg in messages) {
        if (msg['id'] == messageId) {
          msg['content'] = newContent;
          break;
        }
      }
      await _saveMessages(conversationId, messages);
    });
  }

  Future<void> clearAllData() async {
    final conversations = await loadConversations();
    final prefs = await _prefs;

    for (final conv in conversations) {
      await prefs.remove(_messagesKey(conv['id']));
    }
    await prefs.remove(_keyConversations);
  }
}
