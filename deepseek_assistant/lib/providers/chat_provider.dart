import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/api/deepseek_api_client.dart';
import '../core/api/deepseek_chat_service.dart';
import '../core/api/mock_chat_service.dart';
import '../core/models/chat_message.dart';
import '../core/models/chat_response.dart';
import '../core/models/tool_definition.dart';
import '../core/models/app_settings.dart';
import '../core/config/app_config.dart';
import '../core/tools/tool_registry.dart';
import '../core/tools/tool_weather.dart';
import '../core/tools/tool_web_search.dart';
import '../core/rag/rag_context_builder.dart';
import '../core/models/rag_search_result.dart';
import '../data/storage/local_storage_service.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/api_repository.dart';
import 'settings_provider.dart';
import 'rag_provider.dart';
import 'auth_provider.dart' as auth;

enum ChatStatus { idle, loading, streaming, error }

class ChatState {
  final String? currentConversationId;
  final List<ChatMessage> messages;
  final ChatStatus status;
  final String streamingContent;
  final String streamingReasoning;
  final String? errorMessage;
  final int totalTokens;
  final List<ApiConversation> conversations;

  ChatState({
    this.currentConversationId,
    this.messages = const [],
    this.status = ChatStatus.idle,
    this.streamingContent = '',
    this.streamingReasoning = '',
    this.errorMessage,
    this.totalTokens = 0,
    this.conversations = const [],
  });

  ChatState copyWith({
    String? currentConversationId,
    List<ChatMessage>? messages,
    ChatStatus? status,
    String? streamingContent,
    String? streamingReasoning,
    String? errorMessage,
    int? totalTokens,
    List<ApiConversation>? conversations,
  }) {
    return ChatState(
      currentConversationId:
          currentConversationId ?? this.currentConversationId,
      messages: messages ?? this.messages,
      status: status ?? this.status,
      streamingContent: streamingContent ?? this.streamingContent,
      streamingReasoning: streamingReasoning ?? this.streamingReasoning,
      errorMessage: errorMessage,
      totalTokens: totalTokens ?? this.totalTokens,
      conversations: conversations ?? this.conversations,
    );
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(LocalStorageService.instance);
});

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return ChatNotifier(repository, ref);
});

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  final Ref _ref;
  late final ApiRepository _apiRepository;
  final ToolRegistry _toolRegistry = ToolRegistry.instance;
  final _uuid = const Uuid();

  DeepSeekChatService? _chatService;
  CancelToken? _cancelToken;
  ProviderSubscription<auth.AuthState>? _authSubscription;

  ChatNotifier(this._repository, this._ref) : super(ChatState()) {
    _apiRepository = ApiRepository(_ref);
    _listenToAuthChanges();
    // 如果用户已认证（如 token 自动登录），主动加载对话列表
    // 因为 listener 只在状态变化时触发，不会处理初始值
    final authState = _ref.read(auth.authProvider);
    if (authState.isAuthenticated) {
      init();
    }
  }

  void _listenToAuthChanges() {
    _authSubscription?.close();
    _authSubscription = _ref.listen<auth.AuthState>(
      auth.authProvider,
      (previous, next) async {
        if (previous?.isAuthenticated != next.isAuthenticated) {
          if (!next.isAuthenticated) {
            // 用户登出，清除所有聊天状态
            state = ChatState();
          } else {
            // 用户登录，重新初始化
            await init();
          }
        }
      },
    );
  }

  AppSettings get _settings => _ref.read(settingsProvider);

  Future<void> init() async {
    final authState = _ref.read(auth.authProvider);
    if (!authState.isAuthenticated) {
      return;
    }
    
    try {
      final apiSessions = await _apiRepository.getSessions();
      final conversations = apiSessions.map((json) => ApiConversation.fromJson(json)).toList();
      state = ChatState(conversations: conversations);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load sessions: $e');
      }
      state = ChatState();
    }
    _initChatService();
  }

  void _initChatService() {
    if (AppConfig.useMockChatService) {
      _mockChatService = MockChatService();
    } else if (AppConfig.apiKey.isNotEmpty) {
      _chatService = DeepSeekChatService(DeepSeekApiClient.instance);
    }
  }
  
  MockChatService? _mockChatService;

  Future<void> createNewConversation() async {
    try {
      final result = await _apiRepository.createSession(title: '新对话');
      if (result != null) {
        final conv = ApiConversation.fromJson(result);
        final apiSessions = await _apiRepository.getSessions();
        final conversations = apiSessions.map((json) => ApiConversation.fromJson(json)).toList();
        state = ChatState(
          currentConversationId: conv.id.toString(),
          messages: [],
          status: ChatStatus.idle,
          streamingContent: '',
          streamingReasoning: '',
          totalTokens: 0,
          conversations: conversations,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to create conversation: $e');
      }
    }
  }

  Future<void> loadConversation(String conversationId) async {
    final sessionId = int.tryParse(conversationId);
    if (sessionId != null) {
      try {
        final apiMessages = await _apiRepository.getMessages(sessionId);
        final messages = apiMessages.map((json) => ApiMessage.fromJson(json).toChatMessage()).toList();
        final apiSessions = await _apiRepository.getSessions();
        final conversations = apiSessions.map((json) => ApiConversation.fromJson(json)).toList();
        state = state.copyWith(
          currentConversationId: conversationId,
          messages: messages,
          status: ChatStatus.idle,
          streamingContent: '',
          streamingReasoning: '',
          errorMessage: null,
          conversations: conversations,
        );
      } catch (e) {
        if (kDebugMode) {
          print('Failed to load conversation: $e');
        }
        state = state.copyWith(errorMessage: '加载对话失败');
      }
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    final sessionId = int.tryParse(conversationId);
    if (sessionId != null) {
      await _apiRepository.deleteSession(sessionId);
    }
    final apiSessions = await _apiRepository.getSessions();
    final conversations = apiSessions.map((json) => ApiConversation.fromJson(json)).toList();

    if (state.currentConversationId == conversationId) {
      state = state.copyWith(
        currentConversationId: null,
        messages: [],
        conversations: conversations,
      );
    } else {
      state = state.copyWith(conversations: conversations);
    }
  }

  Future<void> renameConversation(String id, String title) async {
    final sessionId = int.tryParse(id);
    if (sessionId != null) {
      await _apiRepository.updateSessionTitle(sessionId, title);
    }
    final apiSessions = await _apiRepository.getSessions();
    final conversations = apiSessions.map((json) => ApiConversation.fromJson(json)).toList();
    state = state.copyWith(conversations: conversations);
  }

  Future<void> sendMessage({
    required String content,
    List<String>? imageBase64List,
  }) async {
    _initChatService();
    if (_chatService == null && _mockChatService == null) {
      state = state.copyWith(
        errorMessage: '请先在设置中配置 API Key',
        status: ChatStatus.error,
      );
      return;
    }

    String conversationId = state.currentConversationId ?? '';
    if (conversationId.isEmpty) {
      final title = content.length > 30 ? '${content.substring(0, 30)}...' : content;
      final result = await _apiRepository.createSession(title: title);
      if (result != null) {
        final conv = ApiConversation.fromJson(result);
        conversationId = conv.id.toString();
        final apiSessions = await _apiRepository.getSessions();
        final conversations = apiSessions.map((json) => ApiConversation.fromJson(json)).toList();
        state = ChatState(
          currentConversationId: conversationId,
          messages: [],
          status: ChatStatus.loading,
          streamingContent: '',
          streamingReasoning: '',
          totalTokens: 0,
          conversations: conversations,
        );
      } else {
        state = state.copyWith(
          status: ChatStatus.error,
          errorMessage: '创建会话失败',
        );
        return;
      }
    }

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: content,
      imageBase64List: imageBase64List,
      timestamp: DateTime.now(),
    );

    final newMessages = [...state.messages, userMessage];
    state = state.copyWith(
      messages: newMessages,
      status: ChatStatus.loading,
      errorMessage: null,
    );

    final sessionId = int.tryParse(conversationId);
    if (sessionId != null) {
      try {
        await _apiRepository.createMessage(sessionId, {
          'role': 'user',
          'content': content,
        });
      } catch (_) {}
    }

    final hasImages = imageBase64List != null && imageBase64List.isNotEmpty;
    final apiMessages = _buildApiMessages(newMessages,
        visionMode: hasImages);
    final tools = (hasImages && !_settings.webSearchEnabled)
        ? <ToolDefinition>[] 
        : _toolRegistry.getDefinitions();

    _cancelToken = CancelToken();

    try {
      await _processStreamResponse(
        conversationId: conversationId,
        apiMessages: apiMessages,
        tools: tools,
        hasImages: hasImages,
      );
    } on DeepSeekApiException catch (e) {
      state = state.copyWith(
        status: ChatStatus.error,
        errorMessage: e.message,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        state = state.copyWith(status: ChatStatus.idle);
      } else {
        state = state.copyWith(
          status: ChatStatus.error,
          errorMessage: '网络请求失败: ${e.message}',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: ChatStatus.error,
        errorMessage: '未知错误: $e',
      );
    }
  }

  Future<void> _processStreamResponse({
    required String conversationId,
    required List<Map<String, dynamic>> apiMessages,
    required List<ToolDefinition> tools,
    bool hasImages = false,
  }) async {
    final chatService = _chatService;
    final mockChatService = _mockChatService;
    
    if (chatService == null && mockChatService == null) return;

    final settings = _settings;

    late Stream<ChatResponse> stream;
    
    if (mockChatService != null) {
      stream = mockChatService.chatStream(
        messages: apiMessages,
        tools: tools.isNotEmpty ? tools : null,
        temperature: settings.temperature,
        maxTokens: settings.maxTokens,
        model: hasImages ? 'mimo-v2.5' : settings.model,
        cancelToken: _cancelToken,
      );
    } else {
      if (chatService != null) {
      stream = chatService.chatStream(
        messages: apiMessages,
        tools: tools.isNotEmpty ? tools : null,
        temperature: settings.temperature,
        maxTokens: settings.maxTokens,
        model: hasImages ? 'mimo-v2.5' : settings.model,
        cancelToken: _cancelToken,
      );
    }

    ChatResponse? lastResponse;
    final messages = [...state.messages];

    int tokenCount = 0;

    await for (final response in stream) {
      lastResponse = response;
      if (response.isStreamDone) break;

      tokenCount++;
      state = state.copyWith(
        status: ChatStatus.streaming,
        streamingContent: response.content,
        streamingReasoning: response.reasoningContent ?? '',
        totalTokens: response.totalTokens,
      );
      if (tokenCount % 3 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (lastResponse == null) return;

    final toolCalls = lastResponse.toolCalls;
    if (toolCalls != null && toolCalls.isNotEmpty) {
      await _handleToolCalls(
        conversationId: conversationId,
        toolCalls: toolCalls,
        messages: messages,
      );
      return;
    }

    final assistantMessage = ChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content: lastResponse.content,
      reasoningContent: lastResponse.reasoningContent,
      timestamp: DateTime.now(),
      shouldShowThinking: _settings.deepThinkingEnabled,
      webSearchEnabled: _settings.webSearchEnabled,
    );

    messages.add(assistantMessage);

    final sessionId = int.tryParse(conversationId);
    if (sessionId != null) {
      try {
        await _apiRepository.createMessage(sessionId, {
          'role': 'assistant',
          'content': lastResponse.content,
          'reasoningContent': lastResponse.reasoningContent,
          'webSearchEnabled': _settings.webSearchEnabled,
        });

        if (state.messages.length <= 1) {
          final title = lastResponse.content.length > 30
              ? '${lastResponse.content.substring(0, 30)}...'
              : lastResponse.content;
          await _apiRepository.updateSessionTitle(sessionId, title);
        }
      } catch (_) {}
    }

    final apiSessions = await _apiRepository.getSessions();
    final conversations = apiSessions.map((json) => ApiConversation.fromJson(json)).toList();
    state = state.copyWith(
      messages: messages,
      status: ChatStatus.idle,
      streamingContent: '',
      streamingReasoning: '',
      conversations: conversations,
      totalTokens: lastResponse.totalTokens,
    );
  }

  Future<void> _handleToolCalls({
    required String conversationId,
    required List<ToolCall> toolCalls,
    required List<ChatMessage> messages,
  }) async {
    final assistantMessage = ChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content: '',
      toolCalls: toolCalls,
      timestamp: DateTime.now(),
    );
    messages.add(assistantMessage);

    await _repository.saveMessage(
      conversationId: conversationId,
      chatMessage: assistantMessage,
    );

    String? ragContext;
    final toolResults = <ChatMessage>[];
    for (final toolCall in toolCalls) {
      final tool = _toolRegistry.getTool(toolCall.function.name);
      if (tool != null) {
        try {
          final args = _parseArgs(toolCall.function.arguments);
          
          // 如果是网络搜索，先设置搜索状态
          if (tool is WebSearchTool) {
            final query = args['query']?.toString() ?? '';
            _ref.read(ragProvider.notifier).setSearching();
            // 临时设置结果，让 UI 能显示查询词
            _ref.read(ragProvider.notifier).setResult(RagSearchResult(
              query: query,
              sources: [],
              combinedContext: '',
            ));
          }
          
          final result = await tool.execute(args);
          toolResults.add(ChatMessage(
            id: _uuid.v4(),
            role: 'tool',
            content: result,
            toolCallId: toolCall.id,
            timestamp: DateTime.now(),
          ));

          if (tool is WebSearchTool && tool.lastResults.isNotEmpty) {
            final sources = tool.lastResults;
            final query = args['query']?.toString() ?? '';
            final builder = RagContextBuilder();
            ragContext = await builder.buildContext(query, sources);

            _ref.read(ragProvider.notifier).setResult(RagSearchResult(
              query: query,
              sources: sources,
              combinedContext: ragContext,
            ));
          }
        } catch (e) {
          toolResults.add(ChatMessage(
            id: _uuid.v4(),
            role: 'tool',
            content: '工具执行失败: $e',
            toolCallId: toolCall.id,
            timestamp: DateTime.now(),
          ));
          _ref.read(ragProvider.notifier).setError(e.toString());
        }
      }
    }

    for (final tr in toolResults) {
      messages.add(tr);
      await _repository.saveMessage(
        conversationId: conversationId,
        chatMessage: tr,
      );
    }

    state = state.copyWith(messages: messages);

    final updatedApiMessages = _buildApiMessages(messages, ragContext: ragContext);
    await _processStreamResponse(
      conversationId: conversationId,
      apiMessages: updatedApiMessages,
      tools: _toolRegistry.getDefinitions(),
    );
  }

  Map<String, dynamic> _parseArgs(String arguments) {
    try {
      return jsonDecode(arguments) as Map<String, dynamic>;
    } catch (e) {
      developer.log('Failed to parse tool arguments: $e', name: 'ChatProvider');
      return {};
    }
  }

  void stopGeneration() {
    _cancelToken?.cancel();
    state = state.copyWith(status: ChatStatus.idle);
  }

  Future<void> regenerateLast() async {
    if (state.messages.isEmpty) return;
    final conversationId = state.currentConversationId;
    if (conversationId == null) return;

    final messages = [...state.messages];
    if (messages.last.role == 'assistant') {
      messages.removeLast();
    }

    state = state.copyWith(messages: messages);

    final apiMessages = _buildApiMessages(messages);
    final tools = _toolRegistry.getDefinitions();
    _cancelToken = CancelToken();

    await _processStreamResponse(
      conversationId: conversationId,
      apiMessages: apiMessages,
      tools: tools,
    );
  }

  String _getSystemPrompt(bool visionMode) {
    if (visionMode) {
      return '你是一个图像理解助手。请仔细观察用户上传的图片，并根据用户的问题进行详细回答。如果用户没有提问，请详细描述图片内容，包括物体、场景、颜色、文字等。请用中文回答。';
    }

    final settings = _settings;
    final now = DateTime.now();
    final currentDate = '${now.year}年${now.month}月${now.day}日';
    
    if (settings.deepThinkingEnabled && settings.webSearchEnabled) {
      return AppConfig.deepThinkingWithWebSearchPrompt.replaceAll('{{CURRENT_DATE}}', currentDate);
    } else if (settings.deepThinkingEnabled) {
      return AppConfig.deepThinkingPrompt;
    } else if (settings.webSearchEnabled) {
      return AppConfig.webSearchPrompt.replaceAll('{{CURRENT_DATE}}', currentDate);
    } else {
      return AppConfig.customThinkingPrompt;
    }
  }

  List<Map<String, dynamic>> _buildApiMessages(
      List<ChatMessage> messages, {bool visionMode = false, String? ragContext}) {
    var systemPrompt = _getSystemPrompt(visionMode);
    if (ragContext != null && ragContext.isNotEmpty) {
      systemPrompt = '$systemPrompt\n\n$ragContext';
    }

    return [
      {'role': 'system', 'content': systemPrompt},
      ...messages.map((m) => m.toApiFormat()),
    ];
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _cancelToken?.cancel();
    super.dispose();
  }
}
