class RagSearchResult {
  final String query;
  final List<WebSource> sources;
  final String combinedContext;
  final DateTime timestamp;

  RagSearchResult({
    required this.query,
    required this.sources,
    required this.combinedContext,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'sources': sources.map((s) => s.toJson()).toList(),
      'combinedContext': combinedContext,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory RagSearchResult.fromJson(Map<String, dynamic> json) {
    return RagSearchResult(
      query: json['query'] as String,
      sources: (json['sources'] as List<dynamic>)
          .map((s) => WebSource.fromJson(s as Map<String, dynamic>))
          .toList(),
      combinedContext: json['combinedContext'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class WebSource {
  final String url;
  final String title;
  final String snippet;
  final String? content;
  final String? summary;
  final String? siteName;
  final String? datePublished;
  final DateTime? fetchedAt;

  WebSource({
    required this.url,
    required this.title,
    required this.snippet,
    this.content,
    this.summary,
    this.siteName,
    this.datePublished,
    this.fetchedAt,
  });

  String get domain {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return url;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'snippet': snippet,
      'content': content,
      'summary': summary,
      'siteName': siteName,
      'datePublished': datePublished,
      'fetchedAt': fetchedAt?.toIso8601String(),
    };
  }

  factory WebSource.fromJson(Map<String, dynamic> json) {
    return WebSource(
      url: json['url'] as String,
      title: json['title'] as String,
      snippet: json['snippet'] as String,
      content: json['content'] as String?,
      summary: json['summary'] as String?,
      siteName: json['siteName'] as String?,
      datePublished: json['datePublished'] as String?,
      fetchedAt: json['fetchedAt'] != null
          ? DateTime.parse(json['fetchedAt'] as String)
          : null,
    );
  }

  WebSource copyWith({
    String? url,
    String? title,
    String? snippet,
    String? content,
    String? summary,
    String? siteName,
    String? datePublished,
    DateTime? fetchedAt,
  }) {
    return WebSource(
      url: url ?? this.url,
      title: title ?? this.title,
      snippet: snippet ?? this.snippet,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      siteName: siteName ?? this.siteName,
      datePublished: datePublished ?? this.datePublished,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}
