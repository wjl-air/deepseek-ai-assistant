import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import 'tool_registry.dart';
import '../models/rag_search_result.dart';
import '../config/app_config.dart';

class _SearchCacheEntry {
  final String result;
  final DateTime timestamp;
  final List<WebSource> sources;

  _SearchCacheEntry({
    required this.result,
    required this.timestamp,
    required this.sources,
  });
}

class WebSearchTool extends AiTool {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  List<WebSource> _lastSources = [];
  
  // 搜索缓存：查询 -> 缓存条目
  final Map<String, _SearchCacheEntry> _searchCache = {};
  static const _cacheDuration = Duration(minutes: 60); // 缓存 60 分钟

  List<WebSource> get lastResults => _lastSources;

  // 规范化查询字符串用于缓存键
  String _normalizeQuery(String query) {
    return query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  // 检查缓存是否有效
  bool _isCacheValid(_SearchCacheEntry? entry) {
    if (entry == null) return false;
    return DateTime.now().difference(entry.timestamp) < _cacheDuration;
  }

  // 清理过期缓存
  void _cleanExpiredCache() {
    final now = DateTime.now();
    _searchCache.removeWhere((key, entry) => 
        now.difference(entry.timestamp) >= _cacheDuration);
  }

  @override
  String get name => 'web_search';

  @override
  String get description =>
      '搜索互联网获取最新信息。适用于需要实时数据、最新新闻或未知话题的场景。';

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
    final query = args['query']?.toString() ?? '';
    if (query.isEmpty) return '错误: 请提供搜索关键词';

    final normalizedQuery = _normalizeQuery(query);
    developer.log('执行搜索: $query', name: 'WebSearch');

    // 先检查缓存
    final cachedEntry = _searchCache[normalizedQuery];
    if (_isCacheValid(cachedEntry)) {
      developer.log('使用缓存的搜索结果', name: 'WebSearch');
      _lastSources = cachedEntry!.sources;
      return cachedEntry.result;
    }

    try {
      final simpleAnswer = _getSimpleAnswer(query);
      if (simpleAnswer != null) {
        return simpleAnswer;
      }

      String result;
      if (AppConfig.bochaApiKey.isNotEmpty) {
        try {
          developer.log('使用博查 API 进行搜索: $query', name: 'WebSearch');
          result = await _searchWithBocha(query, AppConfig.bochaApiKey);
        } catch (e) {
          developer.log('博查搜索失败 (第1次): $e', name: 'WebSearch', error: e);
          // 第一次博查失败，尝试第二次
          try {
            developer.log('重试博查 API 搜索: $query', name: 'WebSearch');
            result = await _searchWithBocha(query, AppConfig.bochaApiKey);
          } catch (e2) {
            developer.log('博查搜索失败 (第2次): $e2', name: 'WebSearch', error: e2);
            // 连续两次失败，回退到 DuckDuckGo
            try {
              developer.log('回退到 DuckDuckGo 搜索: $query', name: 'WebSearch');
              result = await _searchWithDuckDuckGo(query);
            } catch (e3) {
              developer.log('DuckDuckGo 搜索也失败: $e3', name: 'WebSearch', error: e3);
              // 都失败了，返回通用错误
              result = '联网搜索暂时无法使用，请稍后再试';
            }
          }
        }
      } else {
        try {
          developer.log('使用 DuckDuckGo 进行搜索: $query', name: 'WebSearch');
          result = await _searchWithDuckDuckGo(query);
        } catch (e) {
          developer.log('DuckDuckGo 搜索失败: $e', name: 'WebSearch', error: e);
          result = '联网搜索暂时无法使用，请稍后再试';
        }
      }

      // 缓存成功的搜索结果
      if (!result.contains('暂时无法使用') && !result.contains('未找到')) {
        _searchCache[normalizedQuery] = _SearchCacheEntry(
          result: result,
          timestamp: DateTime.now(),
          sources: List.from(_lastSources),
        );
        _cleanExpiredCache(); // 清理过期缓存
      }

      return result;
    } catch (e) {
      developer.log('搜索流程异常: $e', name: 'WebSearch', error: e);
      return '联网搜索暂时无法使用，请稍后再试';
    }
  }

  String? _getSimpleAnswer(String query) {
    final lowerQuery = query.toLowerCase();
    final now = DateTime.now();
    
    bool isDateQuery = lowerQuery.contains('今天') || lowerQuery.contains('日期') || 
                      lowerQuery.contains('几号') || lowerQuery.contains('date') ||
                      lowerQuery.contains('今天是') || lowerQuery.contains('今天的');
    
    if (isDateQuery) {
      final String dateStr = "${now.year}年${now.month}月${now.day}日";
      final List<String> weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"];
      final String weekDay = weekdays[now.weekday - 1];
      final String hourStr = now.hour.toString().padLeft(2, '0');
      final String minuteStr = now.minute.toString().padLeft(2, '0');
      final String timeStr = "$hourStr:$minuteStr";
      
      return "📅 当前时间信息:\n\n日期: $dateStr\n星期: $weekDay\n时间: $timeStr";
    }
    
    return null;
  }

  Future<String> _searchWithBocha(String query, String apiKey) async {
    try {
      developer.log('调用博查 API, URL: https://api.bochaai.com/v1/web-search', name: 'WebSearch');
      
      final response = await _dio.post(
        'https://api.bochaai.com/v1/web-search',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'query': query,
          'count': 10,
          'summary': true,
          'freshness': 'noLimit',
        },
      );

      developer.log('博查 API 响应状态码: ${response.statusCode}', name: 'WebSearch');

      final data = response.data;
      if (data is! Map) {
        developer.log('博查 API 响应不是 Map 类型: $data', name: 'WebSearch');
        _lastSources = [];
        return '🔍 未找到与 "$query" 相关的搜索结果。';
      }

      final webPages = data['data']?['webPages']?['value'];
      if (webPages is! List || webPages.isEmpty) {
        developer.log('博查 API 没有返回搜索结果', name: 'WebSearch');
        _lastSources = [];
        return '🔍 未找到与 "$query" 相关的搜索结果。';
      }

      developer.log('博查 API 找到 ${webPages.length} 个搜索结果', name: 'WebSearch');
      
      _lastSources = webPages.map<WebSource>((item) {
        return WebSource(
          url: item['url']?.toString() ?? '',
          title: item['name']?.toString() ?? '',
          snippet: item['snippet']?.toString() ?? '',
          summary: item['summary']?.toString(),
          siteName: item['siteName']?.toString(),
          datePublished: item['datePublished']?.toString(),
          fetchedAt: DateTime.now(),
        );
      }).toList();

      return _formatResults(query, _lastSources);
    } on DioException catch (e) {
      developer.log('博查 API Dio 异常: ${e.message}', name: 'WebSearch', error: e);
      
      String errorMessage = '';
      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        developer.log('博查 API 响应: $statusCode - $responseData', name: 'WebSearch');
        
        if (statusCode == 401) {
          errorMessage = '❌ 搜索服务认证失败，请检查 API Key 配置';
        } else if (statusCode == 403) {
          errorMessage = '❌ 搜索服务访问受限，请检查 API Key 余额或权限';
        } else if (statusCode == 429) {
          errorMessage = '⏳ 搜索请求过于频繁，请稍后再试';
        } else if (statusCode != null && statusCode >= 500) {
          errorMessage = '⚠️ 搜索服务暂时不可用，请稍后再试';
        } else {
          errorMessage = '❌ 搜索服务返回错误 (状态码: $statusCode)';
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        errorMessage = '⏱️ 搜索请求超时，请检查网络连接后重试';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = '🌐 无法连接到搜索服务，请检查网络连接';
      } else {
        errorMessage = '❌ 搜索失败: ${e.message}';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      developer.log('博查 API 未知异常: $e', name: 'WebSearch', error: e);
      throw Exception('❌ 搜索服务异常，请稍后再试');
    }
  }

  Future<String> _searchWithDuckDuckGo(String query) async {
    try {
      developer.log('调用 DuckDuckGo API', name: 'WebSearch');
      
      final response = await _dio.get(
        'https://api.duckduckgo.com/',
        queryParameters: {
          'q': query,
          'format': 'json',
          'no_html': 1,
          'skip_disambig': 1,
        },
      );

      developer.log('DuckDuckGo API 响应状态码: ${response.statusCode}', name: 'WebSearch');

      final data = response.data;
      
      String abstractText = '';
      String abstractUrl = '';
      String heading = '';

      if (data is Map) {
        final mapData = data as Map<String, dynamic>;
        
        if (mapData.containsKey('AbstractText') && mapData['AbstractText'] != null) {
          abstractText = mapData['AbstractText'].toString();
        }
        
        if (mapData.containsKey('AbstractURL') && mapData['AbstractURL'] != null) {
          abstractUrl = mapData['AbstractURL'].toString();
        }
        
        if (mapData.containsKey('Heading') && mapData['Heading'] != null) {
          heading = mapData['Heading'].toString();
        }

        if (abstractText.isEmpty) {
          if (mapData.containsKey('RelatedTopics')) {
            final relatedTopics = mapData['RelatedTopics'];
            if (relatedTopics is List && relatedTopics.isNotEmpty) {
              final firstTopic = relatedTopics[0];
              if (firstTopic is Map) {
                final topicMap = firstTopic as Map<String, dynamic>;
                if (topicMap.containsKey('Text') && topicMap['Text'] != null) {
                  final topicText = topicMap['Text'].toString();
                  _lastSources = [];
                  return _formatSimpleResult(query, topicText, '');
                }
              }
              if (relatedTopics[0] != null) {
                _lastSources = [];
                return _formatSimpleResult(query, relatedTopics[0].toString(), '');
              }
            }
          }
          _lastSources = [];
          return '🔍 未找到与 "$query" 相关的搜索结果。';
        }
      } else {
        _lastSources = [];
        return '🔍 未找到与 "$query" 相关的搜索结果。';
      }

      _lastSources = [WebSource(
        url: abstractUrl,
        title: heading.isNotEmpty ? heading : query,
        snippet: abstractText,
        fetchedAt: DateTime.now(),
      )];

      return _formatSimpleResult(query, abstractText, abstractUrl, heading);
    } on DioException catch (e) {
      developer.log('DuckDuckGo API Dio 异常: ${e.message}', name: 'WebSearch', error: e);
      
      String errorMessage = '';
      if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        errorMessage = '⏱️ 备用搜索服务超时，请稍后再试';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = '🌐 无法连接到备用搜索服务';
      } else {
        errorMessage = '❌ 备用搜索服务暂时不可用';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      developer.log('DuckDuckGo API 未知异常: $e', name: 'WebSearch', error: e);
      throw Exception('❌ 备用搜索服务异常');
    }
  }

  String _formatResults(String query, List<WebSource> sources) {
    final buffer = StringBuffer();
    
    // 给AI的简洁搜索结果格式，不显示给用户
    buffer.writeln('<search_results>');
    for (var i = 0; i < sources.length; i++) {
      final s = sources[i];
      buffer.writeln('<result index="${i + 1}">');
      buffer.writeln('  <title>${s.title}</title>');
      if (s.summary != null && s.summary!.isNotEmpty) {
        buffer.writeln('  <content>${s.summary}</content>');
      } else if (s.snippet.isNotEmpty) {
        buffer.writeln('  <content>${s.snippet}</content>');
      }
      buffer.writeln('  <url>${s.url}</url>');
      if (s.siteName != null && s.siteName!.isNotEmpty) {
        buffer.writeln('  <source>${s.siteName}</source>');
      }
      buffer.writeln('</result>');
    }
    buffer.writeln('</search_results>');
    
    return buffer.toString();
  }

  String _formatSimpleResult(String query, String content, String url, [String title = '']) {
    final buffer = StringBuffer();
    
    // 给AI的简洁搜索结果格式，不显示给用户
    buffer.writeln('<search_results>');
    buffer.writeln('<result index="1">');
    if (title.isNotEmpty) {
      buffer.writeln('  <title>$title</title>');
    }
    buffer.writeln('  <content>$content</content>');
    if (url.isNotEmpty) {
      buffer.writeln('  <url>$url</url>');
    }
    buffer.writeln('</result>');
    buffer.writeln('</search_results>');

    return buffer.toString();
  }
}
