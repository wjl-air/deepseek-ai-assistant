import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/rag_search_result.dart';

class WebContentExtractor {
  final Dio _dio;

  WebContentExtractor({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          },
        ));

  Future<WebSource?> extractFromUrl(String url) async {
    try {
      final response = await _dio.get(url);
      final html = response.data as String;

      final title = _extractTitle(html);
      final mainContent = _extractMainContent(html);
      final summary = _generateSimpleSummary(mainContent);

      return WebSource(
        url: url,
        title: title,
        snippet: mainContent.substring(0, mainContent.length > 200 ? 200 : mainContent.length),
        content: mainContent,
        summary: summary,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  String _extractTitle(String html) {
    final document = html_parser.parse(html);
    final titleEl = document.querySelector('title');
    return titleEl?.text.trim() ?? 'Untitled';
  }

  String _extractMainContent(String html) {
    final document = html_parser.parse(html);

    document.querySelectorAll('script, style, nav, header, footer, aside, noscript, iframe')
        .forEach((el) => el.remove());

    final body = document.body;
    if (body == null) return '';

    return body.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _generateSimpleSummary(String content) {
    if (content.isEmpty) return '';
    final sentences = content.split(RegExp(r'[.!?。！？；\n]+')).where((s) => s.trim().isNotEmpty).take(3).toList();
    return sentences.join('。') + (sentences.isNotEmpty ? '。' : '');
  }

  String cleanText(String rawText) {
    return rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
