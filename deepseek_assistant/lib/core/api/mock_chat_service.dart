import 'dart:async';
import 'package:dio/dio.dart';
import '../models/chat_message.dart';
import '../models/chat_response.dart';
import '../models/tool_definition.dart';

class MockChatService {
  Stream<ChatResponse> chatStream({
    required List<Map<String, dynamic>> messages,
    List<ToolDefinition>? tools,
    double? temperature,
    int? maxTokens,
    String? model,
    CancelToken? cancelToken,
  }) async* {
    final userMessage = messages.last['content'] as String;
    String responseContent = _generateResponse(userMessage);
    
    yield* _streamResponse(responseContent);
  }

  Stream<ChatResponse> _streamResponse(String content) async* {
    String accumulated = '';
    final words = content.split('');
    
    for (int i = 0; i < words.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      accumulated += words[i];
      
      yield ChatResponse(
        content: accumulated,
        reasoningContent: null,
        finishReason: null,
        toolCalls: null,
        totalTokens: accumulated.length,
        isStreamDone: false,
      );
    }
    
    yield ChatResponse(
      content: accumulated,
      reasoningContent: null,
      finishReason: 'stop',
      toolCalls: null,
      totalTokens: accumulated.length,
      isStreamDone: true,
    );
  }

  String _generateResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();
    
    if (lowerMessage.contains('月') && lowerMessage.contains('号')) {
      final now = DateTime.now();
      return '今天是${now.year}年${now.month}月${now.day}日';
    }
    
    if (lowerMessage.contains('你好') || lowerMessage.contains('您好')) {
      return '你好！我是你的AI助手，很高兴为你服务。请问有什么我可以帮助你的吗？';
    }
    
    if (lowerMessage.contains('时间') || lowerMessage.contains('几点')) {
      final now = DateTime.now();
      return '现在是${now.hour}时${now.minute}分';
    }
    
    if (lowerMessage.contains('天气')) {
      return '抱歉，我目前无法获取实时天气信息。你可以开启联网搜索功能来查询天气。';
    }
    
    if (lowerMessage.contains('计算')) {
      return '我可以帮你进行简单的数学计算。请告诉我你想计算什么。';
    }
    
    if (lowerMessage.contains('翻译')) {
      return '我可以帮你翻译文字。请告诉我需要翻译的内容和目标语言。';
    }
    
    if (lowerMessage.contains('你是谁') || lowerMessage.contains('什么')) {
      return '我是一个AI助手，旨在帮助你解答问题、提供信息和完成各种任务。';
    }
    
    return '这是一个模拟响应。你的问题是："$userMessage"\n\n由于外部API服务暂时不可用，我正在使用模拟模式为你提供服务。你可以继续提问，我会尽力回答你的问题。';
  }
}