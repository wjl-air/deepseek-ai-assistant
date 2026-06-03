import '../models/rag_search_result.dart';
import 'content_summarizer.dart';

class SearchResultProcessor {
  final ContentSummarizer _summarizer = ContentSummarizer();

  Future<RagSearchResult> processQuery(String query, List<WebSource> sources) async {
    final bestSources = selectBestSources(sources);
    final combinedContext = buildCombinedContext(bestSources);

    return RagSearchResult(
      query: query,
      sources: bestSources,
      combinedContext: combinedContext,
    );
  }

  List<WebSource> selectBestSources(List<WebSource> sources) {
    final validSources = sources.where((s) => s.snippet.isNotEmpty || (s.content != null && s.content!.isNotEmpty)).toList();
    validSources.sort((a, b) => b.snippet.length.compareTo(a.snippet.length));
    return validSources.take(5).toList();
  }

  String buildCombinedContext(List<WebSource> sources) {
    final buffer = StringBuffer();

    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      buffer.writeln('--- Source ${i + 1}: ${source.title} ---');
      if (source.summary != null && source.summary!.isNotEmpty) {
        buffer.writeln(source.summary);
      } else {
        buffer.writeln(_summarizer.summarize(source.snippet, maxLength: 150));
      }
      buffer.writeln('URL: ${source.url}');
      buffer.writeln();
    }

    return buffer.toString();
  }

  String buildSystemPrompt(String userQuery, RagSearchResult result) {
    final prompt = StringBuffer();
    prompt.writeln('以下是与用户问题相关的搜索结果，请基于这些信息回答用户问题：');
    prompt.writeln();
    prompt.writeln(result.combinedContext);
    prompt.writeln();
    prompt.writeln('用户问题：$userQuery');
    prompt.writeln();
    prompt.writeln('请在回答中标注信息来源，例如 [1]、[2] 等，引用来源的格式为 [n](URL)。');

    return prompt.toString();
  }
}
