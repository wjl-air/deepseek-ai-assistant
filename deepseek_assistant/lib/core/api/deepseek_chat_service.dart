import 'package:dio/dio.dart';
import 'deepseek_api_client.dart';
import 'sse_parser.dart';
import '../models/chat_message.dart';
import '../models/chat_response.dart';
import '../models/tool_definition.dart';
import '../config/app_config.dart';

class DeepSeekChatService {
  final DeepSeekApiClient _client;

  DeepSeekChatService(this._client);

  Stream<ChatResponse> chatStream({
    required List<Map<String, dynamic>> messages,
    List<ToolDefinition>? tools,
    double? temperature,
    int? maxTokens,
    String? model,
    CancelToken? cancelToken,
  }) async* {
    final requestBody = _buildRequestBody(
      messages: messages,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
      model: model,
    );

    try {
      final response = await _client.postStream(
        path: AppConfig.chatCompletionsPath,
        data: requestBody,
        cancelToken: cancelToken,
      );

      String accumulatedContent = '';
      String accumulatedReasoning = '';
      List<ToolCall>? toolCalls;
      int totalTokens = 0;

      await for (final chunk in SseParser.parse(response.data as ResponseBody)) {
        if (chunk.isDone) break;
        if (cancelToken?.isCancelled == true) break;

        final data = chunk.data;
        final choices = data['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;

        final choice = choices[0] as Map<String, dynamic>;
        final delta = choice['delta'] as Map<String, dynamic>?;
        if (delta == null) continue;

        final content = delta['content'] as String?;
        final reasoning = delta['reasoning_content'] as String?;
        final finishReason = choice['finish_reason'] as String?;

        if (content != null) accumulatedContent += content;
        if (reasoning != null) accumulatedReasoning += reasoning;

        if (delta['tool_calls'] != null) {
          final tcList = delta['tool_calls'] as List;
          for (final tc in tcList) {
            final index = tc['index'] as int;
            toolCalls ??= List.generate(
              tcList.length,
              (_) => ToolCall(
                id: '', type: 'function',
                function: FunctionCall(name: '', arguments: ''),
              ),
            );
            if (index < toolCalls.length) {
              final existing = toolCalls[index];
              toolCalls[index] = ToolCall(
                id: tc['id'] as String? ?? existing.id,
                type: tc['type'] as String? ?? existing.type,
                function: FunctionCall(
                  name: (tc['function'] as Map<String, dynamic>?)?['name'] as String? ?? existing.function.name,
                  arguments: existing.function.arguments + ((tc['function'] as Map<String, dynamic>?)?['arguments'] as String? ?? ''),
                ),
              );
            }
          }
        }

        final usage = data['usage'] as Map<String, dynamic>?;
        if (usage != null) {
          totalTokens = usage['total_tokens'] as int? ?? totalTokens;
        }

        yield ChatResponse(
          content: accumulatedContent,
          reasoningContent: accumulatedReasoning.isNotEmpty ? accumulatedReasoning : null,
          finishReason: finishReason,
          toolCalls: toolCalls,
          totalTokens: totalTokens,
          isStreamDone: false,
        );
      }

      yield ChatResponse(
        content: accumulatedContent,
        reasoningContent: accumulatedReasoning.isNotEmpty ? accumulatedReasoning : null,
        finishReason: 'stop',
        toolCalls: toolCalls,
        totalTokens: totalTokens,
        isStreamDone: true,
      );
    } on DeepSeekApiException {
      rethrow;
    } on DioException {
      rethrow;
    } catch (e) {
      yield ChatResponse(content: '', isStreamDone: true);
    }
  }

  Map<String, dynamic> _buildRequestBody({
    required List<Map<String, dynamic>> messages,
    List<ToolDefinition>? tools,
    double? temperature,
    int? maxTokens,
    String? model,
  }) {
    return {
      'model': model ?? AppConfig.defaultModel,
      'messages': messages,
      'stream': true,
      if (tools != null && tools.isNotEmpty)
        'tools': tools.map((t) => t.toJson()).toList(),
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_completion_tokens': maxTokens,
    };
  }
}
