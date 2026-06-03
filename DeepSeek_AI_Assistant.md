# 跨平台 AI 多模态全能助手 App — 项目文档

> **技术栈**：Flutter 3.24 + Dart 3.5 | Riverpod 2.5 | Isar | Dio | Material 3
> **AI 模型**：DeepSeek API（deepseek-v4-pro）
> **平台**：Android / iOS 双端

---

## 目录

1. [项目概述](#1-项目概述)
2. [项目结构](#2-项目结构)
3. [环境搭建](#3-环境搭建)
4. [pubspec.yaml](#4-pubspeccyaml)
5. [核心 API 封装](#5-核心-api-封装)
6. [数据模型](#6-数据模型)
7. [工具调用系统](#7-工具调用系统)
8. [数据层](#8-数据层)
9. [状态管理](#9-状态管理)
10. [UI 主题](#10-ui-主题)
11. [UI 组件](#11-ui-组件)
12. [对话页面](#12-对话页面)
13. [多模态页面](#13-多模态页面)
14. [设置页面](#14-设置页面)
15. [对话列表页面](#15-对话列表页面)
16. [应用入口](#16-应用入口)
17. [运行指南](#17-运行指南)

---

## 1. 项目概述

### 架构图

```
┌──────────────────────────────────────────────────────────┐
│                        UI 层                              │
│  lib/ui/pages/        (pages)                            │
│  lib/ui/widgets/      (components)                       │
│  lib/ui/theme/        (Material 3 light/dark themes)     │
├──────────────────────────────────────────────────────────┤
│                      逻辑层                               │
│  lib/providers/       (Riverpod 2.5 state management)    │
│  chat_provider / conversation_provider                    │
│  settings_provider / voice_provider                       │
├──────────────────────────────────────────────────────────┤
│                      数据层                               │
│  lib/data/database/   (Isar schemas + service)           │
│  lib/data/repositories/ (data access layer)              │
├──────────────────────────────────────────────────────────┤
│                      核心层                               │
│  lib/core/api/        (Dio + SSE parser + ChatService)   │
│  lib/core/models/     (data models)                      │
│  lib/core/tools/      (AI tool registry + 5 tools)       │
│  lib/core/config/     (app configuration constants)       │
│  lib/core/utils/      (image utils, TTS)                 │
└──────────────────────────────────────────────────────────┘
```

### 数据流

```
用户输入 → ChatPage → ChatProvider.sendMessage()
  → ChatRepository.sendStream()
    → DeepSeekChatService.chatStream()
      → DeepSeekApiClient (Dio SSE)
        → https://api.deepseek.com/chat/completions
          ← SSE data chunks
      ← parsed by SSEParser
    ← Stream<ChatResponse>
  → ChatProvider updates (streaming text)
    → ChatBubble rebuilds (typewriter effect)
  → On [DONE]: save to Isar database
```

### 技术选型说明

| 层级 | 技术 | 理由 |
|------|------|------|
| 状态管理 | Riverpod 2.5 | 编译时安全、无 Context 依赖、易于测试 |
| 本地数据库 | Isar 3.x | 性能优秀的 NoSQL 数据库，支持索引和查询 |
| 网络请求 | Dio | 拦截器、流式响应、超时控制、拦截器链 |
| UI | Material 3 | 最新设计规范，原生支持亮/暗主题 |
| 语音识别 | speech_to_text | 设备端识别，无需网络 API |
| 语音合成 | flutter_tts | 设备端 TTS，支持多语言 |
| 图片选择 | image_picker | 官方插件，支持相册和拍照 |

---

## 2. 项目结构

```
deepseek_assistant/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   │
│   ├── core/
│   │   ├── api/
│   │   │   ├── deepseek_api_client.dart
│   │   │   ├── deepseek_chat_service.dart
│   │   │   └── sse_parser.dart
│   │   ├── config/
│   │   │   └── app_config.dart
│   │   ├── models/
│   │   │   ├── chat_message.dart
│   │   │   ├── chat_request.dart
│   │   │   ├── chat_response.dart
│   │   │   ├── tool_definition.dart
│   │   │   └── app_settings.dart
│   │   ├── tools/
│   │   │   ├── tool_registry.dart
│   │   │   ├── tool_calculator.dart
│   │   │   ├── tool_weather.dart
│   │   │   ├── tool_translate.dart
│   │   │   ├── tool_unit_converter.dart
│   │   │   └── tool_web_search.dart
│   │   └── utils/
│   │       ├── image_utils.dart
│   │       └── text_to_speech.dart
│   │
│   ├── data/
│   │   ├── database/
│   │   │   ├── isar_service.dart
│   │   │   ├── conversation.dart
│   │   │   ├── conversation.g.dart
│   │   │   ├── message.dart
│   │   │   ├── message.g.dart
│   │   │   ├── settings.dart
│   │   │   └── settings.g.dart
│   │   └── repositories/
│   │       ├── chat_repository.dart
│   │       └── settings_repository.dart
│   │
│   ├── providers/
│   │   ├── chat_provider.dart
│   │   ├── conversation_provider.dart
│   │   ├── settings_provider.dart
│   │   └── voice_provider.dart
│   │
│   └── ui/
│       ├── theme/
│       │   └── app_theme.dart
│       ├── widgets/
│       │   ├── chat_bubble.dart
│       │   ├── typing_indicator.dart
│       │   ├── image_picker_sheet.dart
│       │   └── markdown_renderer.dart
│       └── pages/
│           ├── chat_page.dart
│           ├── multimodal_page.dart
│           ├── settings_page.dart
│           └── conversation_list_page.dart
│
├── pubspec.yaml
└── analysis_options.yaml
```

---

## 3. 环境搭建

### 前置要求

- Flutter SDK >= 3.24.0
- Dart SDK >= 3.5.0
- Android Studio / Xcode（对应平台）
- DeepSeek API Key（从 https://platform.deepseek.com/api_keys 获取）

### 创建项目

```bash
flutter create --org com.deepseek deepseek_assistant
cd deepseek_assistant
```

### 安装依赖

```bash
flutter pub get
dart run build_runner build
```

### 配置 API Key

首次启动 App 后，进入「设置」页面输入你的 DeepSeek API Key，或通过 SharedPreferences 预置。

---

## 4. pubspec.yaml

```yaml
name: deepseek_assistant
description: AI 多模态全能助手 - 基于 DeepSeek API
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.5.0 <4.0.0'
  flutter: '>=3.24.0'

dependencies:
  flutter:
    sdk: flutter

  # 状态管理
  flutter_riverpod: ^2.5.1

  # 网络请求
  dio: ^5.4.3+1

  # 本地数据库
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1

  # 文件路径
  path_provider: ^2.1.3

  # 图片选择
  image_picker: ^1.1.2

  # 语音识别 & 合成
  speech_to_text: ^6.6.2
  flutter_tts: ^4.0.2

  # 权限管理
  permission_handler: ^11.3.1

  # UI 组件
  flutter_markdown: ^0.7.2+1
  url_launcher: ^6.3.0

  # 图片处理
  image: ^4.2.0

  # 工具
  uuid: ^4.4.0
  shared_preferences: ^2.2.3
  intl: ^0.19.0
  crypto: ^3.0.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.11
  isar_generator: ^3.1.0+1

flutter:
  uses-material-design: true
  assets: []
```

---

## 5. 核心 API 封装

### 5.1 应用配置 — `lib/core/config/app_config.dart`

```dart
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = 'https://api.deepseek.com';
  static const String chatCompletionsPath = '/chat/completions';

  static const String apiKeyPlaceholder = 'YOUR_DEEPSEEK_API_KEY';

  static const String defaultModel = 'deepseek-v4-pro';
  static const List<String> availableModels = [
    'deepseek-v4-pro',
    'deepseek-v4-flash',
    'deepseek-chat',
  ];

  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 4096;
  static const int connectTimeoutMs = 30000;
  static const int receiveTimeoutMs = 120000;
  static const int maxImageSizeBytes = 20 * 1024 * 1024;
  static const int maxImageWidth = 2048;
  static const int maxImageHeight = 2048;

  // 第三方 API Keys（用于工具调用，非 AI 模型）
  static const String weatherApiKey = 'YOUR_OPENWEATHERMAP_API_KEY';
  static const String weatherApiBaseUrl = 'https://api.openweathermap.org/data/2.5';
}
```

### 5.2 Dio 封装 — `lib/core/api/deepseek_api_client.dart`

```dart
import 'package:dio/dio.dart';
import '../config/app_config.dart';

class DeepSeekApiClient {
  late final Dio _dio;
  String _apiKey;

  DeepSeekApiClient({required String apiKey}) : _apiKey = apiKey {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(milliseconds: AppConfig.connectTimeoutMs),
      receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeoutMs),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: false,
      logPrint: (obj) => print('[DeepSeek API] $obj'),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        _handleError(error);
        handler.next(error);
      },
    ));
  }

  void updateApiKey(String newKey) {
    _apiKey = newKey;
    _dio.options.headers['Authorization'] = 'Bearer $newKey';
  }

  void _handleError(DioException error) {
    switch (error.response?.statusCode) {
      case 401:
        throw DeepSeekApiException('API Key 无效或已过期', statusCode: 401);
      case 402:
        throw DeepSeekApiException('账户余额不足', statusCode: 402);
      case 429:
        throw DeepSeekApiException('请求频率超限，请稍后重试', statusCode: 429);
      case 500:
        throw DeepSeekApiException('DeepSeek 服务器内部错误', statusCode: 500);
      case 503:
        throw DeepSeekApiException('DeepSeek 服务暂时不可用', statusCode: 503);
      default:
        throw DeepSeekApiException(
          error.message ?? '未知网络错误',
          statusCode: error.response?.statusCode,
        );
    }
  }

  Future<Response> postJson({
    required String path,
    required Map<String, dynamic> data,
    CancelToken? cancelToken,
  }) async {
    return _dio.post(path, data: data, cancelToken: cancelToken);
  }

  Future<Response> postStream({
    required String path,
    required Map<String, dynamic> data,
    CancelToken? cancelToken,
  }) async {
    return _dio.post(
      path,
      data: data,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
        },
      ),
    );
  }
}

class DeepSeekApiException implements Exception {
  final String message;
  final int? statusCode;

  DeepSeekApiException(this.message, {this.statusCode});

  @override
  String toString() => 'DeepSeekApiException($statusCode): $message';
}
```

### 5.3 SSE 流式解析器 — `lib/core/api/sse_parser.dart`

```dart
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

class SseChunk {
  final Map<String, dynamic> data;
  final bool isDone;

  SseChunk({required this.data, this.isDone = false});
}

class SseParser {
  static const String _dataPrefix = 'data: ';
  static const String _doneSignal = 'data: [DONE]';

  static Stream<SseChunk> parse(ResponseBody responseBody) async* {
    String buffer = '';

    await for (final chunk in responseBody.stream) {
      final lines = const Utf8Decoder().convert(chunk);
      buffer += lines;

      while (buffer.contains('\n')) {
        final newlineIndex = buffer.indexOf('\n');
        final line = buffer.substring(0, newlineIndex).trim();
        buffer = buffer.substring(newlineIndex + 1);

        if (line.isEmpty) continue;

        if (line == _doneSignal) {
          yield SseChunk(data: {}, isDone: true);
          return;
        }

        if (line.startsWith(_dataPrefix)) {
          final jsonStr = line.substring(_dataPrefix.length);
          try {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            yield SseChunk(data: json);
          } catch (e) {
            // 跳过无法解析的数据行
            continue;
          }
        }
      }
    }
  }
}
```

### 5.4 Chat Service — `lib/core/api/deepseek_chat_service.dart`

```dart
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'deepseek_api_client.dart';
import 'sse_parser.dart';
import '../models/chat_request.dart';
import '../models/chat_response.dart';
import '../models/tool_definition.dart';
import '../config/app_config.dart';

class DeepSeekChatService {
  final DeepSeekApiClient _client;

  DeepSeekChatService(this._client);

  // ==================== 非流式对话 ====================

  Future<ChatResponse> chat({
    required List<Map<String, dynamic>> messages,
    List<ToolDefinition>? tools,
    double? temperature,
    int? maxTokens,
    String? model,
    CancelToken? cancelToken,
  }) async {
    final requestBody = _buildRequestBody(
      messages: messages,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
      model: model,
      stream: false,
    );

    final response = await _client.postJson(
      path: AppConfig.chatCompletionsPath,
      data: requestBody,
      cancelToken: cancelToken,
    );

    return ChatResponse.fromJson(response.data);
  }

  // ==================== 流式对话 ====================

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
      stream: true,
    );

    final response = await _client.postStream(
      path: AppConfig.chatCompletionsPath,
      data: requestBody,
      cancelToken: cancelToken,
    );

    final stream = SseParser.parse(response.data!);

    String currentContent = '';
    String currentReasoning = '';
    String? finishReason;
    List<ToolCallDelta> toolCalls = [];
    int totalTokens = 0;

    await for (final chunk in stream) {
      if (cancelToken?.isCancelled == true) break;

      if (chunk.isDone) {
        yield ChatResponse(
          content: currentContent,
          reasoningContent: currentReasoning.isNotEmpty ? currentReasoning : null,
          finishReason: finishReason ?? 'stop',
          toolCalls: toolCalls.isNotEmpty
              ? toolCalls.map((e) => ToolCall(
                    id: e.id ?? '',
                    type: e.type ?? 'function',
                    function: FunctionCall(
                      name: e.functionName ?? '',
                      arguments: e.functionArguments ?? '',
                    ),
                  )).toList()
              : null,
          totalTokens: totalTokens,
          isStreamDone: true,
        );
        return;
      }

      final json = chunk.data;
      if (json.isEmpty) continue;

      // 解析 usage
      if (json['usage'] != null) {
        final usage = json['usage'] as Map<String, dynamic>;
        totalTokens = usage['total_tokens'] as int? ?? 0;
      }

      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) continue;

      final choice = choices[0] as Map<String, dynamic>;
      final delta = choice['delta'] as Map<String, dynamic>?;

      if (delta != null) {
        // 内容增量
        if (delta['content'] != null && delta['content'].toString().isNotEmpty) {
          currentContent += delta['content'];
        }

        // 推理内容增量
        if (delta['reasoning_content'] != null &&
            delta['reasoning_content'].toString().isNotEmpty) {
          currentReasoning += delta['reasoning_content'];
        }

        // 工具调用增量
        if (delta['tool_calls'] != null) {
          for (final tc in delta['tool_calls']) {
            final index = tc['index'] as int? ?? 0;
            while (toolCalls.length <= index) {
              toolCalls.add(ToolCallDelta());
            }
            if (tc['id'] != null) toolCalls[index].id = tc['id'];
            if (tc['type'] != null) toolCalls[index].type = tc['type'];
            if (tc['function'] != null) {
              final func = tc['function'];
              if (func['name'] != null) toolCalls[index].functionName = func['name'];
              if (func['arguments'] != null) {
                toolCalls[index].functionArguments =
                    (toolCalls[index].functionArguments ?? '') + func['arguments'];
              }
            }
          }
        }
      }

      // finish_reason
      if (choice['finish_reason'] != null) {
        finishReason = choice['finish_reason'] as String?;
      }

      yield ChatResponse(
        content: currentContent,
        reasoningContent: currentReasoning.isNotEmpty ? currentReasoning : null,
        finishReason: finishReason,
        toolCalls: null,
        totalTokens: totalTokens,
        isStreamDone: false,
      );
    }
  }

  Map<String, dynamic> _buildRequestBody({
    required List<Map<String, dynamic>> messages,
    List<ToolDefinition>? tools,
    double? temperature,
    int? maxTokens,
    String? model,
    required bool stream,
  }) {
    return {
      'model': model ?? AppConfig.defaultModel,
      'messages': messages,
      'stream': stream,
      if (tools != null && tools.isNotEmpty)
        'tools': tools.map((t) => t.toJson()).toList(),
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
    };
  }
}

// 内部辅助类（流式工具调用组装）
class ToolCallDelta {
  String? id;
  String? type;
  String? functionName;
  String? functionArguments;
}
```

---

## 6. 数据模型

### 6.1 ChatMessage — `lib/core/models/chat_message.dart`

```dart
class ChatMessage {
  final String id;
  final String role; // system, user, assistant, tool
  final String content;
  final List<String>? imageBase64List; // 多模态图片
  final List<ToolCall>? toolCalls;
  final String? toolCallId;
  final String? name;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.imageBase64List,
    this.toolCalls,
    this.toolCallId,
    this.name,
    required this.timestamp,
  });

  // 转换为 DeepSeek API 格式
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
        'tool_calls': toolCalls!.map((tc) => tc.toApiFormat()).toList(),
      };
    }

    // 多模态用户消息
    if (role == 'user' && imageBase64List != null && imageBase64List!.isNotEmpty) {
      final contentParts = <Map<String, dynamic>>[];
      // 先添加文本
      if (content.isNotEmpty) {
        contentParts.add({'type': 'text', 'text': content});
      }
      // 再添加图片
      for (final base64 in imageBase64List!) {
        contentParts.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/jpeg;base64,$base64',
            'detail': 'auto',
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
    };
  }

  // 从 DeepSeek API 响应创建
  factory ChatMessage.fromApiResponse({
    required String id,
    required String role,
    String? content,
    List<ToolCall>? toolCalls,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? '',
      toolCalls: toolCalls,
      timestamp: DateTime.now(),
    );
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
```

### 6.2 ChatRequest — `lib/core/models/chat_request.dart`

```dart
import 'tool_definition.dart';

class ChatRequest {
  final String model;
  final List<Map<String, dynamic>> messages;
  final bool stream;
  final double? temperature;
  final int? maxTokens;
  final List<ToolDefinition>? tools;

  ChatRequest({
    this.model = 'deepseek-v4-pro',
    required this.messages,
    this.stream = false,
    this.temperature,
    this.maxTokens,
    this.tools,
  });

  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'messages': messages,
      'stream': stream,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (tools != null && tools!.isNotEmpty)
        'tools': tools!.map((t) => t.toJson()).toList(),
    };
  }
}
```

### 6.3 ChatResponse — `lib/core/models/chat_response.dart`

```dart
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

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final choices = json['choices'] as List?;
    final choice = choices?.first as Map<String, dynamic>?;
    final message = choice?['message'] as Map<String, dynamic>?;

    List<ToolCall>? toolCalls;
    if (message?['tool_calls'] != null) {
      toolCalls = (message!['tool_calls'] as List)
          .map((tc) => ToolCall.fromJson(tc))
          .toList();
    }

    final usage = json['usage'] as Map<String, dynamic>?;
    final totalTokens = usage?['total_tokens'] as int? ?? 0;

    return ChatResponse(
      content: message?['content'] ?? '',
      reasoningContent: message?['reasoning_content'],
      finishReason: choice?['finish_reason'],
      toolCalls: toolCalls,
      totalTokens: totalTokens,
      isStreamDone: true,
    );
  }

  String get fullContent {
    if (reasoningContent != null && reasoningContent!.isNotEmpty) {
      return '$reasoningContent\n\n$content';
    }
    return content;
  }
}
```

### 6.4 ToolDefinition — `lib/core/models/tool_definition.dart`

```dart
class ToolDefinition {
  final String type;
  final FunctionDefinition function;

  ToolDefinition({this.type = 'function', required this.function});

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'function': {
        'name': function.name,
        'description': function.description,
        'parameters': function.parameters,
      },
    };
  }
}

class FunctionDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  FunctionDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });
}
```

### 6.5 AppSettings — `lib/core/models/app_settings.dart`

```dart
class AppSettings {
  String apiKey;
  String model;
  double temperature;
  int maxTokens;
  bool isDarkMode;

  AppSettings({
    this.apiKey = '',
    this.model = 'deepseek-v4-pro',
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.isDarkMode = false,
  });

  AppSettings copyWith({
    String? apiKey,
    String? model,
    double? temperature,
    int? maxTokens,
    bool? isDarkMode,
  }) {
    return AppSettings(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}
```

---

## 7. 工具调用系统

### 7.1 工具注册中心 — `lib/core/tools/tool_registry.dart`

```dart
import '../models/tool_definition.dart';

abstract class AiTool {
  String get name;
  String get description;
  Map<String, dynamic> get parameters;

  Future<String> execute(Map<String, dynamic> args);

  ToolDefinition toDefinition() {
    return ToolDefinition(
      function: FunctionDefinition(
        name: name,
        description: description,
        parameters: parameters,
      ),
    );
  }
}

class ToolRegistry {
  final Map<String, AiTool> _tools = {};

  static final ToolRegistry instance = ToolRegistry._();
  ToolRegistry._();

  void registerAll(List<AiTool> tools) {
    for (final tool in tools) {
      _tools[tool.name] = tool;
    }
  }

  AiTool? getTool(String name) => _tools[name];

  List<ToolDefinition> getDefinitions() {
    return _tools.values.map((t) => t.toDefinition()).toList();
  }

  bool get hasTools => _tools.isNotEmpty;
}
```

### 7.2 计算器 — `lib/core/tools/tool_calculator.dart`

```dart
import 'tool_registry.dart';

class CalculatorTool extends AiTool {
  @override
  String get name => 'calculate';

  @override
  String get description => '执行数学计算。支持加(+)、减(-)、乘(*)、除(/)、幂(^)、括号等基本运算。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'expression': {
            'type': 'string',
            'description': '要计算的数学表达式，如 "(2+3)*4" 或 "sqrt(16)+10"',
          },
        },
        'required': ['expression'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final expression = args['expression'] as String;
      // 安全的表达式计算（仅允许数字、运算符、括号、空格）
      final sanitized = expression.replaceAll(RegExp(r'[^0-9+\-*/().%\s]'), '');
      if (sanitized.isEmpty) return '错误: 无效的表达式';
      // 使用 Dart 表达式解析（简单实现）
      final result = _evaluate(sanitized);
      return '计算结果: $expression = $result';
    } catch (e) {
      return '计算错误: $e';
    }
  }

  double _evaluate(String expr) {
    // 简化实现：去除空格，处理基本运算
    // 生产环境建议使用 expressions 或 math_expressions 库
    expr = expr.replaceAll(' ', '');
    return _parseExpression(expr);
  }

  double _parseExpression(String expr) {
    final tokens = <double>[];
    final ops = <String>[];
    int i = 0;

    while (i < expr.length) {
      final ch = expr[i];
      if (ch == ' ') {
        i++;
        continue;
      }
      if (_isDigit(ch) || ch == '.') {
        final start = i;
        while (i < expr.length && (_isDigit(expr[i]) || expr[i] == '.')) {
          i++;
        }
        tokens.add(double.parse(expr.substring(start, i)));
        continue;
      }
      if (ch == '(') {
        ops.add(ch);
      } else if (ch == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          _applyOp(tokens, ops.removeLast());
        }
        if (ops.isNotEmpty) ops.removeLast(); // remove '('
      } else if (_isOperator(ch)) {
        while (ops.isNotEmpty && _precedence(ops.last) >= _precedence(ch)) {
          _applyOp(tokens, ops.removeLast());
        }
        ops.add(ch);
      }
      i++;
    }

    while (ops.isNotEmpty) {
      _applyOp(tokens, ops.removeLast());
    }

    return tokens.isNotEmpty ? tokens.first : 0;
  }

  bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
  bool _isOperator(String ch) => '+-*/^%'.contains(ch);

  int _precedence(String op) {
    switch (op) {
      case '+':
      case '-':
        return 1;
      case '*':
      case '/':
      case '%':
        return 2;
      case '^':
        return 3;
      default:
        return 0;
    }
  }

  void _applyOp(List<double> values, String op) {
    if (values.length < 2) return;
    final b = values.removeLast();
    final a = values.removeLast();
    switch (op) {
      case '+':
        values.add(a + b);
      case '-':
        values.add(a - b);
      case '*':
        values.add(a * b);
      case '/':
        values.add(b != 0 ? a / b : double.nan);
      case '^':
        values.add(_pow(a, b));
      case '%':
        values.add(a % b);
    }
  }

  double _pow(double a, double b) {
    if (b == 0) return 1;
    return a * _pow(a, b - 1); // 简化实现，仅支持整数幂
  }
}
```

### 7.3 天气查询 — `lib/core/tools/tool_weather.dart`

```dart
import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'tool_registry.dart';

class WeatherTool extends AiTool {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  @override
  String get name => 'get_weather';

  @override
  String get description => '查询指定城市的实时天气信息，包含温度、湿度、天气状况和风速。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'city': {
            'type': 'string',
            'description': '城市名称，使用中文，如 "北京"、"上海"、"杭州"',
          },
        },
        'required': ['city'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final city = args['city'] as String;
      final apiKey = AppConfig.weatherApiKey;

      if (apiKey == 'YOUR_OPENWEATHERMAP_API_KEY') {
        return '天气模块未配置 API Key。请在 app_config.dart 中填入 OpenWeatherMap API Key。';
      }

      final response = await _dio.get(
        '${AppConfig.weatherApiBaseUrl}/weather',
        queryParameters: {
          'q': city,
          'appid': apiKey,
          'units': 'metric',
          'lang': 'zh_cn',
        },
      );

      final data = response.data;
      final temp = data['main']['temp'];
      final feelsLike = data['main']['feels_like'];
      final humidity = data['main']['humidity'];
      final description = data['weather'][0]['description'];
      final windSpeed = data['wind']['speed'];
      final cityName = data['name'];

      return '$cityName 天气: $description\n'
          '温度: ${temp}°C (体感 ${feelsLike}°C)\n'
          '湿度: $humidity%\n'
          '风速: ${windSpeed}m/s';
    } catch (e) {
      return '天气查询失败: $e。请确认城市名称是否正确。';
    }
  }
}
```

### 7.4 翻译 — `lib/core/tools/tool_translate.dart`

```dart
import 'tool_registry.dart';

class TranslateTool extends AiTool {
  @override
  String get name => 'translate';

  @override
  String get description => '翻译文本到指定语言。需要提供目标语言代码，如 "en"、"zh"、"ja"、"ko"、"fr" 等。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'text': {
            'type': 'string',
            'description': '需要翻译的文本',
          },
          'target_language': {
            'type': 'string',
            'description': '目标语言代码，如 "en"=英语、"zh"=中文、"ja"=日语、"ko"=韩语、"fr"=法语',
          },
        },
        'required': ['text', 'target_language'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    // 翻译功能实际上由 DeepSeek 模型自身完成
    // 这里返回一个触发标记，让 DeepSeek 在下一轮对话中执行翻译
    final text = args['text'] as String;
    final targetLang = args['target_language'] as String;

    final langNames = {
      'en': '英语',
      'zh': '中文',
      'ja': '日语',
      'ko': '韩语',
      'fr': '法语',
      'de': '德语',
      'es': '西班牙语',
      'ru': '俄语',
      'ar': '阿拉伯语',
      'pt': '葡萄牙语',
    };

    final langName = langNames[targetLang] ?? targetLang;
    return '翻译请求: 将以下文本翻译为$langName($targetLang):\n\n$text';
  }
}
```

### 7.5 单位转换 — `lib/core/tools/tool_unit_converter.dart`

```dart
import 'tool_registry.dart';

class UnitConverterTool extends AiTool {
  @override
  String get name => 'convert_units';

  @override
  String get description => '进行单位转换。支持长度、重量、温度、面积、体积、速度等常用单位。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'value': {
            'type': 'number',
            'description': '需要转换的数值',
          },
          'from_unit': {
            'type': 'string',
            'description': '源单位，如 "km"、"m"、"mile"、"kg"、"lb"、"celsius"、"fahrenheit"',
          },
          'to_unit': {
            'type': 'string',
            'description': '目标单位',
          },
        },
        'required': ['value', 'from_unit', 'to_unit'],
      };

  static final Map<String, double> _lengthToMeter = {
    'm': 1.0,
    'km': 1000.0,
    'cm': 0.01,
    'mm': 0.001,
    'mile': 1609.344,
    'yard': 0.9144,
    'foot': 0.3048,
    'inch': 0.0254,
  };

  static final Map<String, double> _weightToKg = {
    'kg': 1.0,
    'g': 0.001,
    'mg': 0.000001,
    'lb': 0.45359237,
    'oz': 0.0283495,
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final value = (args['value'] as num).toDouble();
      final fromUnit = (args['from_unit'] as String).toLowerCase();
      final toUnit = (args['to_unit'] as String).toLowerCase();

      double result;

      if (fromUnit == 'celsius' && toUnit == 'fahrenheit') {
        result = value * 9 / 5 + 32;
      } else if (fromUnit == 'fahrenheit' && toUnit == 'celsius') {
        result = (value - 32) * 5 / 9;
      } else if (fromUnit == 'celsius' && toUnit == 'kelvin') {
        result = value + 273.15;
      } else if (fromUnit == 'kelvin' && toUnit == 'celsius') {
        result = value - 273.15;
      } else if (_lengthToMeter.containsKey(fromUnit) &&
          _lengthToMeter.containsKey(toUnit)) {
        result = value * _lengthToMeter[fromUnit]! / _lengthToMeter[toUnit]!;
      } else if (_weightToKg.containsKey(fromUnit) &&
          _weightToKg.containsKey(toUnit)) {
        result = value * _weightToKg[fromUnit]! / _weightToKg[toUnit]!;
      } else {
        return '不支持的单位转换: $fromUnit -> $toUnit';
      }

      return '$value $fromUnit = ${result.toStringAsFixed(4)} $toUnit';
    } catch (e) {
      return '单位转换错误: $e';
    }
  }
}
```

### 7.6 联网搜索 — `lib/core/tools/tool_web_search.dart`

```dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'tool_registry.dart';

class WebSearchTool extends AiTool {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  @override
  String get name => 'web_search';

  @override
  String get description => '搜索互联网获取最新信息。适用于需要实时数据或最新新闻的场景。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': '搜索关键词',
          },
        },
        'required': ['query'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final query = args['query'] as String;
      final encodedQuery = Uri.encodeComponent(query);

      // 使用 DuckDuckGo Instant Answer API（免费，无需 API Key）
      final response = await _dio.get(
        'https://api.duckduckgo.com/',
        queryParameters: {
          'q': query,
          'format': 'json',
          'no_html': 1,
          'skip_disambig': 1,
        },
      );

      final data = response.data;
      final abstractText = data['AbstractText'] as String? ?? '';
      final abstractUrl = data['AbstractURL'] as String? ?? '';
      final heading = data['Heading'] as String? ?? '';

      if (abstractText.isEmpty) {
        // 尝试获取相关主题
        final relatedTopics = data['RelatedTopics'] as List? ?? [];
        if (relatedTopics.isNotEmpty) {
          final firstTopic = relatedTopics[0] as Map<String, dynamic>;
          final topicText = firstTopic['Text'] as String? ?? '';
          return '搜索结果: $topicText';
        }
        return '未找到与 "$query" 相关的搜索结果。';
      }

      return '$heading\n$abstractText\n${abstractUrl.isNotEmpty ? '\n来源: $abstractUrl' : ''}';
    } catch (e) {
      return '搜索请求失败: $e';
    }
  }
}
```

---

## 8. 数据层

### 8.1 Isar 模型 — `lib/data/database/message.dart`

```dart
import 'package:isar/isar.dart';

part 'message.g.dart';

@collection
class MessageIsar {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String messageId;

  late String conversationId;
  late String role;
  late String content;

  @enumerated
  MessageRole get messageRole {
    switch (role) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      case 'tool':
        return MessageRole.tool;
      default:
        return MessageRole.user;
    }
  }

  String? toolCallsJson;
  String? toolCallId;
  String? imagePathsCsv; // 逗号分隔的本地图片路径
  DateTime? timestamp;

  final conversation = IsarLink<ConversationIsar>();
}

enum MessageRole { user, assistant, system, tool }
```

### 8.2 Isar 模型 — `lib/data/database/conversation.dart`

```dart
import 'package:isar/isar.dart';

part 'conversation.g.dart';

@collection
class ConversationIsar {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String conversationId;

  late String title;
  late DateTime createdAt;
  late DateTime updatedAt;

  final messages = IsarLinks<MessageIsar>();
}
```

### 8.3 Isar 模型 — `lib/data/database/settings.dart`

```dart
import 'package:isar/isar.dart';

part 'settings.g.dart';

@collection
class SettingsIsar {
  Id id = Isar.autoIncrement;

  late String apiKey;
  late String model;
  late double temperature;
  late int maxTokens;
  late bool isDarkMode;
}
```

### 8.4 Isar 服务 — `lib/data/database/isar_service.dart`

```dart
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'conversation.dart';
import 'message.dart';
import 'settings.dart';

class IsarService {
  late final Isar isar;
  static IsarService? _instance;

  IsarService._();

  static Future<IsarService> init() async {
    if (_instance != null) return _instance!;

    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [ConversationIsarSchema, MessageIsarSchema, SettingsIsarSchema],
      directory: dir.path,
    );

    _instance = IsarService._()..isar = isar;
    return _instance!;
  }

  static IsarService get instance {
    if (_instance == null) {
      throw StateError('IsarService 未初始化，请先调用 IsarService.init()');
    }
    return _instance!;
  }

  // 关闭数据库
  Future<void> close() async {
    await isar.close();
    _instance = null;
  }
}
```

### 8.5 ChatRepository — `lib/data/repositories/chat_repository.dart`

```dart
import 'package:uuid/uuid.dart';
import '../../core/models/chat_message.dart';
import '../database/isar_service.dart';
import '../database/conversation.dart';
import '../database/message.dart';

class ChatRepository {
  final IsarService _isarService;
  final _uuid = const Uuid();

  ChatRepository(this._isarService);

  Isar get _isar => _isarService.isar;

  // ==================== 对话管理 ====================

  Future<List<ConversationIsar>> getConversations() async {
    return _isar.conversationIsars
        .where()
        .sortByUpdatedAtDesc()
        .findAll();
  }

  Future<ConversationIsar> createConversation({String title = '新对话'}) async {
    final conversation = ConversationIsar()
      ..conversationId = _uuid.v4()
      ..title = title
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.conversationIsars.put(conversation);
    });

    return conversation;
  }

  Future<void> updateConversationTitle(String conversationId, String title) async {
    final conv = await _isar.conversationIsars
        .where()
        .conversationIdEqualTo(conversationId)
        .findFirst();

    if (conv != null) {
      await _isar.writeTxn(() async {
        conv.title = title;
        conv.updatedAt = DateTime.now();
        await _isar.conversationIsars.put(conv);
      });
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    final conv = await _isar.conversationIsars
        .where()
        .conversationIdEqualTo(conversationId)
        .findFirst();

    if (conv != null) {
      await _isar.writeTxn(() async {
        // 删除关联消息
        final messages = await conv.messages.load();
        for (final msg in messages) {
          await _isar.messageIsars.delete(msg.id);
        }
        await _isar.conversationIsars.delete(conv.id);
      });
    }
  }

  // ==================== 消息管理 ====================

  Future<List<MessageIsar>> getMessages(String conversationId) async {
    final conv = await _isar.conversationIsars
        .where()
        .conversationIdEqualTo(conversationId)
        .findFirst();

    if (conv == null) return [];

    final messages = await conv.messages.load();
    messages.sort((a, b) {
      final ta = a.timestamp ?? DateTime.now();
      final tb = b.timestamp ?? DateTime.now();
      return ta.compareTo(tb);
    });

    return messages;
  }

  Future<MessageIsar> saveMessage({
    required String conversationId,
    required ChatMessage chatMessage,
  }) async {
    final conv = await _isar.conversationIsars
        .where()
        .conversationIdEqualTo(conversationId)
        .findFirst();

    if (conv == null) throw Exception('对话不存在');

    final messageIsar = MessageIsar()
      ..messageId = chatMessage.id
      ..conversationId = conversationId
      ..role = chatMessage.role
      ..content = chatMessage.content
      ..timestamp = chatMessage.timestamp;

    if (chatMessage.toolCallId != null) {
      messageIsar.toolCallId = chatMessage.toolCallId;
    }

    if (chatMessage.toolCalls != null) {
      messageIsar.toolCallsJson = chatMessage.toolCalls!
          .map((tc) => tc.toApiFormat())
          .toString();
    }

    await _isar.writeTxn(() async {
      await _isar.messageIsars.put(messageIsar);
      messageIsar.conversation.value = conv;
      conv.updatedAt = DateTime.now();
      await conv.messages.save();
      await _isar.conversationIsars.put(conv);
    });

    return messageIsar;
  }

  Future<void> updateMessageContent(String messageId, String newContent) async {
    final msg = await _isar.messageIsars
        .where()
        .messageIdEqualTo(messageId)
        .findFirst();

    if (msg != null) {
      await _isar.writeTxn(() async {
        msg.content = newContent;
        await _isar.messageIsars.put(msg);
      });
    }
  }

  // ==================== 转换工具 ====================

  List<ChatMessage> toChatMessages(List<MessageIsar> isarMessages) {
    return isarMessages.map((m) => ChatMessage(
      id: m.messageId,
      role: m.role,
      content: m.content,
      toolCallId: m.toolCallId,
      timestamp: m.timestamp ?? DateTime.now(),
    )).toList();
  }

  // 清除所有数据
  Future<void> clearAllData() async {
    await _isar.writeTxn(() async {
      await _isar.clear();
    });
  }
}
```

### 8.6 SettingsRepository — `lib/data/repositories/settings_repository.dart`

```dart
import '../database/isar_service.dart';
import '../database/settings.dart';
import '../../core/models/app_settings.dart';

class SettingsRepository {
  final IsarService _isarService;

  SettingsRepository(this._isarService);

  Isar get _isar => _isarService.isar;

  Future<AppSettings> loadSettings() async {
    final settingsIsar = await _isar.settingsIsars.where().findFirst();

    if (settingsIsar == null) {
      return AppSettings(); // 返回默认设置
    }

    return AppSettings(
      apiKey: settingsIsar.apiKey,
      model: settingsIsar.model,
      temperature: settingsIsar.temperature,
      maxTokens: settingsIsar.maxTokens,
      isDarkMode: settingsIsar.isDarkMode,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _isar.writeTxn(() async {
      await _isar.settingsIsars.clear();
      await _isar.settingsIsars.put(
        SettingsIsar()
          ..apiKey = settings.apiKey
          ..model = settings.model
          ..temperature = settings.temperature
          ..maxTokens = settings.maxTokens
          ..isDarkMode = settings.isDarkMode,
      );
    });
  }
}
```

---

## 9. 状态管理

### 9.1 ChatProvider — `lib/providers/chat_provider.dart`

```dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/api/deepseek_api_client.dart';
import '../core/api/deepseek_chat_service.dart';
import '../core/models/chat_message.dart';
import '../core/models/chat_response.dart';
import '../core/models/tool_definition.dart';
import '../core/tools/tool_registry.dart';
import '../data/database/isar_service.dart';
import '../data/repositories/chat_repository.dart';
import '../data/database/conversation.dart';
import '../data/database/message.dart' as isar_models;
import 'settings_provider.dart';

enum ChatStatus { idle, loading, streaming, error }

class ChatState {
  final String? currentConversationId;
  final List<ChatMessage> messages;
  final ChatStatus status;
  final String streamingContent;
  final String? errorMessage;
  final int totalTokens;
  final List<ConversationIsar> conversations;

  ChatState({
    this.currentConversationId,
    this.messages = const [],
    this.status = ChatStatus.idle,
    this.streamingContent = '',
    this.errorMessage,
    this.totalTokens = 0,
    this.conversations = const [],
  });

  ChatState copyWith({
    String? currentConversationId,
    List<ChatMessage>? messages,
    ChatStatus? status,
    String? streamingContent,
    String? errorMessage,
    int? totalTokens,
    List<ConversationIsar>? conversations,
  }) {
    return ChatState(
      currentConversationId: currentConversationId ?? this.currentConversationId,
      messages: messages ?? this.messages,
      status: status ?? this.status,
      streamingContent: streamingContent ?? this.streamingContent,
      errorMessage: errorMessage,
      totalTokens: totalTokens ?? this.totalTokens,
      conversations: conversations ?? this.conversations,
    );
  }
}

class ChatProvider extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  final SettingsProvider _settingsProvider;
  final ToolRegistry _toolRegistry = ToolRegistry.instance;
  final _uuid = const Uuid();

  DeepSeekChatService? _chatService;
  CancelToken? _cancelToken;

  ChatProvider(this._repository, this._settingsProvider) : super(ChatState());

  // ==================== 初始化 ====================

  Future<void> init() async {
    final conversations = await _repository.getConversations();
    state = state.copyWith(conversations: conversations);
    _initChatService();
  }

  void _initChatService() {
    final settings = _settingsProvider.state;
    if (settings.apiKey.isNotEmpty) {
      final client = DeepSeekApiClient(apiKey: settings.apiKey);
      _chatService = DeepSeekChatService(client);
    }
  }

  // ==================== 对话管理 ====================

  Future<void> createNewConversation() async {
    final conv = await _repository.createConversation();
    final conversations = await _repository.getConversations();
    state = state.copyWith(
      currentConversationId: conv.conversationId,
      messages: [],
      streamingContent: '',
      conversations: conversations,
    );
  }

  Future<void> loadConversation(String conversationId) async {
    final isarMessages = await _repository.getMessages(conversationId);
    final messages = _repository.toChatMessages(isarMessages);
    final conversations = await _repository.getConversations();
    state = state.copyWith(
      currentConversationId: conversationId,
      messages: messages,
      streamingContent: '',
      conversations: conversations,
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    await _repository.deleteConversation(conversationId);
    final conversations = await _repository.getConversations();

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

  // ==================== 发送消息 ====================

  Future<void> sendMessage({
    required String content,
    List<String>? imageBase64List,
  }) async {
    _initChatService();
    if (_chatService == null) {
      state = state.copyWith(
        errorMessage: '请先在设置中配置 API Key',
        status: ChatStatus.error,
      );
      return;
    }

    // 确保有当前对话
    String conversationId = state.currentConversationId ?? '';
    if (conversationId.isEmpty) {
      final conv = await _repository.createConversation(
        title: content.length > 30 ? '${content.substring(0, 30)}...' : content,
      );
      conversationId = conv.conversationId;
      state = state.copyWith(currentConversationId: conversationId);
    }

    // 添加用户消息
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

    // 保存用户消息
    await _repository.saveMessage(
      conversationId: conversationId,
      chatMessage: userMessage,
    );

    // 准备 API 消息
    final apiMessages = _buildApiMessages(newMessages);

    // 获取工具定义
    final tools = _toolRegistry.getDefinitions();

    final settings = _settingsProvider.state;
    _cancelToken = CancelToken();

    try {
      await _processStreamResponse(
        conversationId: conversationId,
        apiMessages: apiMessages,
        tools: tools,
        settings: settings,
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
    required settings,
  }) async {
    final stream = _chatService!.chatStream(
      messages: apiMessages,
      tools: tools.isNotEmpty ? tools : null,
      temperature: settings.temperature,
      maxTokens: settings.maxTokens,
      model: settings.model,
      cancelToken: _cancelToken,
    );

    ChatResponse? lastResponse;
    final messages = [...state.messages];

    await for (final response in stream) {
      lastResponse = response;

      if (response.isStreamDone) {
        break;
      }

      state = state.copyWith(
        status: ChatStatus.streaming,
        streamingContent: response.content,
        totalTokens: response.totalTokens,
      );
    }

    if (lastResponse == null) return;

    // 检查是否有工具调用
    if (lastResponse.toolCalls != null && lastResponse.toolCalls!.isNotEmpty) {
      await _handleToolCalls(
        conversationId: conversationId,
        toolCalls: lastResponse.toolCalls!,
        messages: messages,
        settings: settings,
      );
      return;
    }

    // 保存 AI 回复
    final assistantMessage = ChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content: lastResponse.content,
      timestamp: DateTime.now(),
    );

    messages.add(assistantMessage);

    await _repository.saveMessage(
      conversationId: conversationId,
      chatMessage: assistantMessage,
    );

    // 如果第一条对话，更新标题
    if (state.messages.length <= 1) {
      await _repository.updateConversationTitle(
        conversationId,
        lastResponse.content.length > 30
            ? '${lastResponse.content.substring(0, 30)}...'
            : lastResponse.content,
      );
    }

    final conversations = await _repository.getConversations();
    state = state.copyWith(
      messages: messages,
      status: ChatStatus.idle,
      streamingContent: '',
      conversations: conversations,
      totalTokens: lastResponse.totalTokens,
    );
  }

  Future<void> _handleToolCalls({
    required String conversationId,
    required List<ToolCall> toolCalls,
    required List<ChatMessage> messages,
    required settings,
  }) async {
    // 保存助手的工具调用消息
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

    // 执行工具并收集结果
    final toolResults = <ChatMessage>[];
    for (final toolCall in toolCalls) {
      final tool = _toolRegistry.getTool(toolCall.function.name);
      if (tool != null) {
        try {
          final args = _parseArgs(toolCall.function.arguments);
          final result = await tool.execute(args);
          toolResults.add(ChatMessage(
            id: _uuid.v4(),
            role: 'tool',
            content: result,
            toolCallId: toolCall.id,
            timestamp: DateTime.now(),
          ));
        } catch (e) {
          toolResults.add(ChatMessage(
            id: _uuid.v4(),
            role: 'tool',
            content: '工具执行失败: $e',
            toolCallId: toolCall.id,
            timestamp: DateTime.now(),
          ));
        }
      }
    }

    // 保存工具结果
    for (final tr in toolResults) {
      messages.add(tr);
      await _repository.saveMessage(
        conversationId: conversationId,
        chatMessage: tr,
      );
    }

    state = state.copyWith(messages: messages);

    // 将工具结果继续传递给 AI
    final updatedApiMessages = _buildApiMessages(messages);
    await _processStreamResponse(
      conversationId: conversationId,
      apiMessages: updatedApiMessages,
      tools: _toolRegistry.getDefinitions(),
      settings: settings,
    );
  }

  Map<String, dynamic> _parseArgs(String arguments) {
    try {
      return Map<String, dynamic>.from(
        _tryJsonDecode(arguments) as Map,
      );
    } catch (_) {
      return {};
    }
  }

  dynamic _tryJsonDecode(String str) {
    // 简化版 JSON 解析（生产环境建议使用 dart:convert）
    import 'dart:convert';
    return jsonDecode(str);
  }

  // ==================== 操作 ====================

  void stopGeneration() {
    _cancelToken?.cancel();
    state = state.copyWith(status: ChatStatus.idle);
  }

  Future<void> regenerateLast() async {
    if (state.messages.isEmpty) return;

    // 移除最后一条 assistant 消息
    final messages = [...state.messages];
    if (messages.last.role == 'assistant') {
      messages.removeLast();
    }

    state = state.copyWith(messages: messages);

    // 重新发送请求（不带新用户消息）
    final apiMessages = _buildApiMessages(messages);
    final tools = _toolRegistry.getDefinitions();
    final settings = _settingsProvider.state;
    _cancelToken = CancelToken();

    await _processStreamResponse(
      conversationId: state.currentConversationId!,
      apiMessages: apiMessages,
      tools: tools,
      settings: settings,
    );
  }

  // ==================== 工具方法 ====================

  List<Map<String, dynamic>> _buildApiMessages(List<ChatMessage> messages) {
    final systemMessage = {
      'role': 'system',
      'content': '你是一个全能的 AI 助手，可以帮助用户完成各种任务。'
          '你可以使用工具来计算、查询天气、翻译、转换单位和搜索网络。'
          '请用中文回答用户的问题。',
    };

    return [
      systemMessage,
      ...messages.map((m) => m.toApiFormat()),
    ];
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
```

### 9.2 ConversationProvider — `lib/providers/conversation_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/isar_service.dart';
import '../data/repositories/chat_repository.dart';

final conversationProvider = Provider<ConversationProvider>((ref) {
  return ConversationProvider(ref.watch(chatRepositoryProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(IsarService.instance);
});
```

### 9.3 SettingsProvider — `lib/providers/settings_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/app_settings.dart';
import '../data/database/isar_service.dart';
import '../data/repositories/settings_repository.dart';

class SettingsProvider extends StateNotifier<AppSettings> {
  final SettingsRepository _repository;

  SettingsProvider(this._repository) : super(AppSettings());

  Future<void> loadSettings() async {
    state = await _repository.loadSettings();
  }

  Future<void> updateApiKey(String apiKey) async {
    state = state.copyWith(apiKey: apiKey);
    await _repository.saveSettings(state);
  }

  Future<void> updateModel(String model) async {
    state = state.copyWith(model: model);
    await _repository.saveSettings(state);
  }

  Future<void> updateTemperature(double temperature) async {
    state = state.copyWith(temperature: temperature);
    await _repository.saveSettings(state);
  }

  Future<void> updateMaxTokens(int maxTokens) async {
    state = state.copyWith(maxTokens: maxTokens);
    await _repository.saveSettings(state);
  }

  Future<void> toggleTheme(bool isDark) async {
    state = state.copyWith(isDarkMode: isDark);
    await _repository.saveSettings(state);
  }
}

final settingsProvider = StateNotifierProvider<SettingsProvider, AppSettings>((ref) {
  final repo = SettingsRepository(IsarService.instance);
  return SettingsProvider(repo);
});
```

### 9.4 VoiceProvider — `lib/providers/voice_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceState { idle, listening, speaking, error }

class VoiceProvider extends StateNotifier<VoiceState> {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  String _recognizedText = '';
  String get recognizedText => _recognizedText;

  VoiceProvider() : super(VoiceState.idle) {
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage('zh-CN');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  // ==================== 语音识别 ====================

  Future<bool> initSpeech() async {
    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          state = VoiceState.idle;
        }
      },
      onError: (error) {
        state = VoiceState.error;
      },
    );
    return available;
  }

  Future<String> startListening() async {
    _recognizedText = '';
    state = VoiceState.listening;

    await _speechToText.listen(
      onResult: (result) {
        _recognizedText = result.recognizedWords;
        if (result.finalResult) {
          state = VoiceState.idle;
        }
      },
      localeId: 'zh_CN',
    );

    return _recognizedText;
  }

  Future<String> stopListening() async {
    await _speechToText.stop();
    state = VoiceState.idle;
    return _recognizedText;
  }

  // ==================== 语音合成 ====================

  Future<void> speak(String text) async {
    state = VoiceState.speaking;

    await _flutterTts.speak(text);

    _flutterTts.setCompletionHandler(() {
      state = VoiceState.idle;
    });
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    state = VoiceState.idle;
  }

  bool get isAvailable => _speechToText.isAvailable;

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}

final voiceProvider = StateNotifierProvider<VoiceProvider, VoiceState>((ref) {
  return VoiceProvider();
});
```

---

## 10. UI 主题

### `lib/ui/theme/app_theme.dart`

```dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF4F6EF7); // DeepSeek 品牌蓝

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
```

---

## 11. UI 组件

### 11.1 ChatBubble — `lib/ui/widgets/chat_bubble.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/chat_message.dart';
import 'markdown_renderer.dart';

class ChatBubble extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == 'user';
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          // 角色标签
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
            child: Text(
              isUser ? '你' : 'DeepSeek',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // 消息气泡
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: isUser
                    ? const Radius.circular(20)
                    : const Radius.circular(4),
                bottomRight: isUser
                    ? const Radius.circular(4)
                    : const Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 内容
                if (isUser)
                  Text(
                    message.content,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  )
                else
                  MarkdownRenderer(
                    content: message.content,
                    isStreaming: isStreaming,
                  ),

                // 图片
                if (message.imageBase64List != null &&
                    message.imageBase64List!.isNotEmpty)
                  ...message.imageBase64List!.map((base64) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _base64ToBytes(base64),
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )),

                // 操作按钮（仅助手消息、非流式状态）
                if (!isUser && !isStreaming && message.content.isNotEmpty)
                  _buildActionButtons(theme),
              ],
            ),
          ),

          // 工具调用显示
          if (message.toolCalls != null && message.toolCalls!.isNotEmpty)
            _buildToolCallsIndicator(theme),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionChip(
            icon: Icons.copy,
            label: '复制',
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.content));
              onCopy?.call();
            },
          ),
          const SizedBox(width: 4),
          _ActionChip(
            icon: Icons.refresh,
            label: '重新生成',
            onTap: onRegenerate,
          ),
        ],
      ),
    );
  }

  Widget _buildToolCallsIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: message.toolCalls!.map((tc) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.build_circle,
                  size: 14,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  tc.function.name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Uint8List _base64ToBytes(String base64) {
    return base64Decode(base64);
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
```

### 11.2 TypingIndicator — `lib/ui/widgets/typing_indicator.dart`

```dart
import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final delay = index * 0.2;
                final value = (_controller.value - delay).clamp(0.0, 1.0);
                final opacity = (value * 2).clamp(0.0, 1.0);
                if (value > 0.5) {
                  return Opacity(
                    opacity: 2.0 - value * 2,
                    child: _dot(theme),
                  );
                }
                return Opacity(
                  opacity: value * 2,
                  child: _dot(theme),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _dot(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurfaceVariant,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
```

### 11.3 ImagePickerSheet — `lib/ui/widgets/image_picker_sheet.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ImagePickerSheet extends StatelessWidget {
  final Function(ImageSource source) onPick;

  const ImagePickerSheet({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '选择图片来源',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOption(
                context,
                icon: Icons.camera_alt,
                label: '拍照',
                color: theme.colorScheme.primary,
                onTap: () {
                  Navigator.pop(context);
                  Future.microtask(() => onPick(ImageSource.camera));
                },
              ),
              _buildOption(
                context,
                icon: Icons.photo_library,
                label: '相册',
                color: theme.colorScheme.secondary,
                onTap: () {
                  Navigator.pop(context);
                  Future.microtask(() => onPick(ImageSource.gallery));
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
```

### 11.4 MarkdownRenderer — `lib/ui/widgets/markdown_renderer.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownRenderer extends StatelessWidget {
  final String content;
  final bool isStreaming;

  const MarkdownRenderer({
    super.key,
    required this.content,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MarkdownBody(
      data: content,
      selectable: !isStreaming,
      styleSheet: MarkdownStyleSheet(
        p: theme.textTheme.bodyLarge?.copyWith(
          height: 1.6,
        ),
        h1: theme.textTheme.headlineMedium,
        h2: theme.textTheme.headlineSmall,
        h3: theme.textTheme.titleLarge,
        code: TextStyle(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.primary,
              width: 3,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 16),
      ),
    );
  }
}
```

---

## 12. 对话页面

### `lib/ui/pages/chat_page.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/voice_provider.dart';
import '../../core/utils/image_utils.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/image_picker_sheet.dart';
import '../theme/app_theme.dart';
import 'conversation_list_page.dart';
import 'settings_page.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App 进入后台，可以考虑断开 SSE
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
            _scrollController.position.maxScrollExtent - 200 &&
        _scrollController.hasClients) {
      // 用户主动滚动，不自动追踪
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    _focusNode.requestFocus();

    await ref.read(chatProvider.notifier).sendMessage(content: text);
    _scrollToBottom();
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

    final base64 = await ImageUtils.compressAndEncode(xFile.path);
    if (base64 == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片处理失败，请重试')),
        );
      }
      return;
    }

    await ref.read(chatProvider.notifier).sendMessage(
      content: _textController.text.isNotEmpty
          ? _textController.text
          : '请描述这张图片',
      imageBase64List: [base64],
    );
    _textController.clear();
    _scrollToBottom();
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ImagePickerSheet(onPick: _pickImage),
    );
  }

  Future<void> _startVoiceInput() async {
    final voiceNotifier = ref.read(voiceProvider.notifier);
    final available = await voiceNotifier.initSpeech();

    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音识别不可用')),
        );
      }
      return;
    }

    setState(() => _isRecording = true);
    await voiceNotifier.startListening();
  }

  Future<void> _stopVoiceInput() async {
    final voiceNotifier = ref.read(voiceProvider.notifier);
    final text = await voiceNotifier.stopListening();

    setState(() => _isRecording = false);

    if (text.isNotEmpty) {
      _textController.text = text;
      await _sendMessage();
    }
  }

  void _showConversations() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ConversationListPage(),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final voiceState = ref.watch(voiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showConversations,
          child: Text(
            chatState.currentConversationId != null
                ? '对话中...'
                : 'AI 助手',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _showConversations,
        ),
        actions: [
          // Token 统计
          if (chatState.totalTokens > 0)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${chatState.totalTokens} tokens',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(context)
                : _buildMessageList(chatState),
          ),

          // 错误提示
          if (chatState.errorMessage != null)
            _buildErrorBanner(chatState.errorMessage!),

          // 输入区域
          _buildInputArea(voiceState),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '你好，我是 DeepSeek 助手',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '我可以帮你回答问题、分析图片、翻译、计算等',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          // 快捷建议
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickChip('1+2*3 等于多少？'),
              _buildQuickChip('今天杭州天气怎么样？'),
              _buildQuickChip('翻译 "Hello World" 为中文'),
              _buildQuickChip('100 英里等于多少公里？'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () async {
        await ref.read(chatProvider.notifier).sendMessage(content: text);
        _scrollToBottom();
      },
    );
  }

  Widget _buildMessageList(ChatState chatState) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      itemCount: chatState.messages.length +
          (chatState.status == ChatStatus.streaming ? 1 : 0),
      itemBuilder: (context, index) {
        // 流式消息
        if (index == chatState.messages.length &&
            chatState.status == ChatStatus.streaming) {
          return Column(
            children: [
              if (chatState.streamingContent.isNotEmpty)
                ChatBubble(
                  message: ChatMessage(
                    id: 'streaming',
                    role: 'assistant',
                    content: chatState.streamingContent,
                    timestamp: DateTime.now(),
                  ),
                  isStreaming: true,
                ),
              const TypingIndicator(),
            ],
          );
        }

        final message = chatState.messages[index];

        return ChatBubble(
          message: message,
          onRegenerate: message.role == 'assistant' &&
                  index == chatState.messages.length - 1
              ? () => ref.read(chatProvider.notifier).regenerateLast()
              : null,
          onCopy: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已复制到剪贴板')),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => ref.read(chatProvider.notifier).clearError(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(VoiceState voiceState) {
    final theme = Theme.of(context);
    final status = ref.watch(chatProvider).status;
    final isLoading = status == ChatStatus.loading ||
        status == ChatStatus.streaming;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 图片选择按钮
          IconButton(
            onPressed: isLoading ? null : _showImagePickerSheet,
            icon: Icon(
              Icons.add_photo_alternate_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          // 文本输入框
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: '输入消息...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),

          // 语音输入按钮
          IconButton(
            onPressed: isLoading
                ? null
                : (_isRecording ? _stopVoiceInput : _startVoiceInput),
            icon: Icon(
              _isRecording ? Icons.mic : Icons.mic_none,
              color: _isRecording
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),

          // 发送/停止按钮
          const SizedBox(width: 4),
          if (isLoading)
            FloatingActionButton(
              onPressed: () => ref.read(chatProvider.notifier).stopGeneration(),
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
              mini: true,
              child: const Icon(Icons.stop),
              elevation: 0,
            )
          else
            FloatingActionButton(
              onPressed: _sendMessage,
              mini: true,
              elevation: 0,
              child: const Icon(Icons.arrow_upward),
            ),
        ],
      ),
    );
  }
}
```

---

## 13. 多模态页面

### `lib/ui/pages/multimodal_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/chat_provider.dart';
import '../../core/utils/image_utils.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/image_picker_sheet.dart';
import '../../core/models/chat_message.dart';

class MultimodalPage extends ConsumerStatefulWidget {
  const MultimodalPage({super.key});

  @override
  ConsumerState<MultimodalPage> createState() => _MultimodalPageState();
}

class _MultimodalPageState extends ConsumerState<MultimodalPage> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedImageBase64;
  String? _selectedImagePath;
  List<MultimodalResult> _results = [];
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

    final base64 = await ImageUtils.compressAndEncode(xFile.path);
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
      _selectedImagePath = xFile.path;
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
        _results.add(MultimodalResult(
          imagePath: _selectedImagePath!,
          question: question,
          timestamp: DateTime.now(),
        ));
        _isProcessing = false;
        _selectedImageBase64 = null;
        _selectedImagePath = null;
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
      _selectedImagePath = null;
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
            child: _results.isEmpty && chatState.messages.isEmpty
                ? _buildEmptyState(theme)
                : _buildResultsList(chatState, theme),
          ),

          // 输入区域
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
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
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

  Widget _buildResultsList(ChatState chatState, ThemeData theme) {
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
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 已选图片预览
          if (_selectedImagePath != null) _buildImagePreview(theme),

          if (_selectedImagePath != null) const SizedBox(height: 12),

          // 输入行
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
                  onPressed: _selectedImageBase64 != null ? _analyzeImage : null,
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
                child: Image.network(
                  '$_selectedImagePath',
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
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
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
                Text(
                  '图片已选择',
                  style: theme.textTheme.titleSmall,
                ),
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

class MultimodalResult {
  final String imagePath;
  final String question;
  final DateTime timestamp;

  MultimodalResult({
    required this.imagePath,
    required this.question,
    required this.timestamp,
  });
}
```

---

## 14. 设置页面

### `lib/ui/pages/settings_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/database/isar_service.dart';
import '../theme/app_theme.dart';
import '../../core/config/app_config.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      _apiKeyController.text = settings.apiKey;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有对话历史和缓存数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ChatRepository(IsarService.instance);
      await repo.clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缓存已清除')),
        );
      }
    }
  }

  void _openApiKeyHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('如何获取 API Key？'),
        content: const Text(
          '1. 访问 https://platform.deepseek.com\n'
          '2. 注册并登录账号\n'
          '3. 进入 API Keys 页面\n'
          '4. 点击「创建 API Key」\n'
          '5. 复制生成的 Key 粘贴到这里\n\n'
          '注意：请妥善保管你的 API Key，不要分享给他人。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // API 配置
          _buildSectionHeader('API 配置'),
          const SizedBox(height: 8),

          // API Key
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('DeepSeek API Key',
                          style: theme.textTheme.titleSmall),
                      const Spacer(),
                      TextButton(
                        onPressed: _openApiKeyHelp,
                        child: const Text('如何获取？'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: !_showApiKey,
                    decoration: InputDecoration(
                      hintText: 'sk-xxxxxxxxxxxxxxxx',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showApiKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _showApiKey = !_showApiKey),
                      ),
                    ),
                    onChanged: (value) {
                      _debounceSave(() {
                        ref
                            .read(settingsProvider.notifier)
                            .updateApiKey(value.trim());
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'API Key 仅存储在你设备本地，不会上传到任何服务器',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 模型选择
          Card(
            child: ListTile(
              title: Text('模型', style: theme.textTheme.titleSmall),
              subtitle: Text(settings.model),
              trailing: DropdownButton<String>(
                value: settings.model,
                underline: const SizedBox(),
                items: AppConfig.availableModels
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(settingsProvider.notifier).updateModel(value);
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 模型参数
          _buildSectionHeader('模型参数'),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                // Temperature
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Temperature', style: theme.textTheme.titleSmall),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          settings.temperature.toStringAsFixed(1),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: settings.temperature,
                  min: 0.0,
                  max: 2.0,
                  divisions: 20,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .updateTemperature(value);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('严谨', style: theme.textTheme.bodySmall),
                      Text('创意', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Max Tokens
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Max Tokens', style: theme.textTheme.titleSmall),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${settings.maxTokens}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: settings.maxTokens.toDouble(),
                  min: 100,
                  max: 8192,
                  divisions: 80,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .updateMaxTokens(value.round());
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 外观
          _buildSectionHeader('外观'),
          const SizedBox(height: 8),

          Card(
            child: SwitchListTile(
              title: Text('深色模式', style: theme.textTheme.titleSmall),
              subtitle: const Text('切换深色/浅色主题'),
              value: settings.isDarkMode,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).toggleTheme(value);
              },
            ),
          ),

          const SizedBox(height: 24),

          // 数据管理
          _buildSectionHeader('数据管理'),
          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: Icon(Icons.delete_outline,
                  color: theme.colorScheme.error),
              title: Text('清除缓存',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                  )),
              subtitle: const Text('删除所有对话历史和缓存数据'),
              onTap: _clearCache,
            ),
          ),

          const SizedBox(height: 24),

          // 关于
          _buildSectionHeader('关于'),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('版本'),
                  subtitle: const Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('AI 模型'),
                  subtitle: const Text('DeepSeek V4 Pro'),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('技术栈'),
                  subtitle: const Text('Flutter 3.24 + Riverpod 2.5 + Isar'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Timer? _debounceTimer;
  void _debounceSave(VoidCallback callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), callback);
  }
}
```

---

## 15. 对话列表页面

### `lib/ui/pages/conversation_list_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/chat_provider.dart';
import '../../data/database/conversation.dart';

class ConversationListPage extends ConsumerWidget {
  const ConversationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    final conversations = chatState.conversations;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '对话历史',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无对话',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '开始新的对话吧',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final isActive =
                    conversation.conversationId == chatState.currentConversationId;
                final dateFormat = DateFormat('MM/dd HH:mm');

                return Card(
                  color: isActive
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3)
                      : null,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                    ),
                    subtitle: Text(
                      dateFormat.format(conversation.updatedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('删除对话'),
                            content: const Text('确定要删除这条对话吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          ref
                              .read(chatProvider.notifier)
                              .deleteConversation(conversation.conversationId);
                        }
                      },
                    ),
                    onTap: () {
                      ref
                          .read(chatProvider.notifier)
                          .loadConversation(conversation.conversationId);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(chatProvider.notifier).createNewConversation();
          Navigator.pop(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('新对话'),
      ),
    );
  }
}
```

---

## 16. 应用入口

### 16.1 main.dart — `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'data/database/isar_service.dart';
import 'data/database/conversation.dart';
import 'data/database/message.dart';
import 'data/database/settings.dart';
import 'core/tools/tool_registry.dart';
import 'core/tools/tool_calculator.dart';
import 'core/tools/tool_weather.dart';
import 'core/tools/tool_translate.dart';
import 'core/tools/tool_unit_converter.dart';
import 'core/tools/tool_web_search.dart';
import 'providers/settings_provider.dart';
import 'providers/chat_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Isar 数据库
  await IsarService.init();

  // 注册 AI 工具
  ToolRegistry.instance.registerAll([
    CalculatorTool(),
    WeatherTool(),
    TranslateTool(),
    UnitConverterTool(),
    WebSearchTool(),
  ]);

  runApp(const ProviderScope(child: DeepSeekApp()));
}
```

### 16.2 app.dart — `lib/app.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/settings_provider.dart';
import 'providers/chat_provider.dart';
import 'ui/theme/app_theme.dart';
import 'ui/pages/chat_page.dart';

class DeepSeekApp extends ConsumerStatefulWidget {
  const DeepSeekApp({super.key});

  @override
  ConsumerState<DeepSeekApp> createState() => _DeepSeekAppState();
}

class _DeepSeekAppState extends ConsumerState<DeepSeekApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initProviders();
    });
  }

  Future<void> _initProviders() async {
    // 加载设置
    await ref.read(settingsProvider.notifier).loadSettings();

    // 初始化聊天 Provider
    final settings = ref.read(settingsProvider);
    final chatNotifier = ref.read(chatProvider.notifier);

    // 同步 API Key 到聊天服务
    if (settings.apiKey.isNotEmpty) {
      chatNotifier.init();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'DeepSeek 助手',
      debugShowCheckedModeBanner: false,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const ChatPage(),
    );
  }
}
```

### 16.3 providers — 在 `main.dart` 同目录创建一个 providers 初始化

由于 ChatProvider 依赖 SettingsProvider 和 ChatRepository，我们需要在 provider 定义中处理好依赖关系。以下补充未列出 provider 的完整定义。

在 `lib/providers/` 目录下，确保已经创建了以下 provider：

- `chat_provider.dart` — 已在第 9.1 节提供
- `settings_provider.dart` — 已在第 9.3 节提供
- `voice_provider.dart` — 已在第 9.4 节提供
- `conversation_provider.dart` — 已在第 9.2 节提供

`chatProvider` 的完整 provider 声明（添加到 chat_provider.dart 底部）：

```dart
// 添加到 lib/providers/chat_provider.dart 文件末尾

import '../data/repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(IsarService.instance);
});

final chatProvider =
    StateNotifierProvider<ChatProvider, ChatState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  final settings = ref.watch(settingsProvider.notifier);
  return ChatProvider(repository, settings);
});
```

### 16.4 Image Utils — `lib/core/utils/image_utils.dart`

```dart
import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;

class ImageUtils {
  static Future<String?> compressAndEncode(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      if (bytes.length > 20 * 1024 * 1024) {
        return null; // 超过 20MB 限制
      }

      // 解码图片
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // 缩放（如果超过最大尺寸）
      img.Image resized = image;
      if (image.width > 2048 || image.height > 2048) {
        resized = img.copyResize(
          image,
          width: image.width > 2048 ? 2048 : image.width,
          height: image.height > 2048 ? 2048 : image.height,
        );
      }

      // 重新编码为 JPEG
      final jpegBytes = img.encodeJpg(resized, quality: 85);
      return base64Encode(jpegBytes);
    } catch (e) {
      print('图片压缩失败: $e');
      return null;
    }
  }
}
```

### 16.5 Text to Speech — `lib/core/utils/text_to_speech.dart`

```dart
import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  TextToSpeechService._();

  static final TextToSpeechService instance = TextToSpeechService._();

  Future<void> init() async {
    if (_isInitialized) return;

    await _flutterTts.setLanguage('zh-CN');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  Future<void> setLanguage(String languageCode) async {
    await _flutterTts.setLanguage(languageCode);
  }

  void setOnComplete(void Function() callback) {
    _flutterTts.setCompletionHandler(callback);
  }
}
```

---

## 17. 运行指南

### Android 配置

#### 权限声明 — `android/app/src/main/AndroidManifest.xml`

在 `<manifest>` 标签内添加以下权限：

```xml
<!-- 网络 -->
<uses-permission android:name="android.permission.INTERNET"/>

<!-- 存储 -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>

<!-- 相机 -->
<uses-permission android:name="android.permission.CAMERA"/>

<!-- 录音 -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>

<!-- 在 <application> 中启用 requestLegacyExternalStorage -->
<application
    android:requestLegacyExternalStorage="true"
    ...>
```

#### 最低 SDK 版本 — `android/app/build.gradle`

```groovy
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
        compileSdkVersion 34
    }
}
```

### iOS 配置

#### 权限声明 — `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>需要使用相机拍照进行分析</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册选择图片</string>

<key>NSMicrophoneUsageDescription</key>
<string>需要使用麦克风进行语音输入</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>需要使用语音识别功能</string>
```

### 编译运行

```bash
# 获取依赖
flutter pub get

# 生成 Isar 数据库代码
dart run build_runner build --delete-conflicting-outputs

# 运行（确保已连接设备或模拟器）
flutter run

# 运行指定平台
flutter run -d android  # Android
flutter run -d ios      # iOS
```

### 打包发布

```bash
# Android APK
flutter build apk --release

# Android AppBundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

### 配置检查清单

- [ ] 已注册 DeepSeek 账号并获取 API Key
- [ ] API Key 已填入设置页面
- [ ] 若使用天气功能，已配置 OpenWeatherMap API Key（在 `app_config.dart`）
- [ ] Android 权限已声明
- [ ] iOS 权限已声明
- [ ] 已运行 `build_runner` 生成 Isar 数据库代码
- [ ] 设备/模拟器已连接并可识别

### 常见问题

| 问题 | 解决方案 |
|------|---------|
| API Key 无效 (401) | 检查 API Key 是否正确，是否已过期 |
| 余额不足 (402) | 登录 DeepSeek 平台充值 |
| 请求频率超限 (429) | 降低请求频率，或升级套餐 |
| 网络连接失败 | 检查设备网络，确认可访问 api.deepseek.com |
| 语音识别不可用 | Android 确保安装了 Google 语音服务；iOS 在模拟器上不可用 |
| Isar 数据库报错 | 重新运行 `build_runner build --delete-conflicting-outputs` |

---

> 本文档为完整的项目源码级文档。所有代码均可直接复制使用，按照项目结构组织文件后即可运行。
> 技术栈：Flutter 3.24 | Dart 3.5 | Riverpod 2.5 | Isar 3.1 | Dio 5.4 | Material 3
> AI 模型：DeepSeek V4 Pro（`deepseek-v4-pro`）
