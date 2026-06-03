import '../models/rag_search_result.dart';
import 'search_result_processor.dart';

class RagContextBuilder {
  final SearchResultProcessor _processor = SearchResultProcessor();

  Future<String> buildContext(String query, List<WebSource> sources) async {
    final result = await _processor.processQuery(query, sources);
    return _processor.buildSystemPrompt(query, result);
  }

  String buildSimpleContext(String query, List<Map<String, String>> simpleSources) {
    final buffer = StringBuffer();
    buffer.writeln('用户问题：$query');
    buffer.writeln();
    buffer.writeln('参考信息：');

    for (var i = 0; i < simpleSources.length; i++) {
      final source = simpleSources[i];
      buffer.writeln('[$i] ${source['title'] ?? 'Unknown'}');
      buffer.writeln('${source['content'] ?? ''}');
      if (source['url'] != null) {
        buffer.writeln('来源：${source['url']}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
