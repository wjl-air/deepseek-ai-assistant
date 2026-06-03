class ContentSummarizer {
  String summarize(String content, {int maxLength = 200}) {
    if (content.isEmpty) return '';

    final sentences = content
        .split(RegExp(r'[.!?。！？；\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final buffer = StringBuffer();
    for (final sentence in sentences) {
      if (buffer.length + sentence.length > maxLength) {
        break;
      }
      if (buffer.isNotEmpty) {
        buffer.write('. ');
      }
      buffer.write(sentence);
    }

    if (buffer.isNotEmpty && !buffer.toString().endsWith('.')) {
      buffer.write('.');
    }

    return buffer.toString();
  }

  List<String> extractKeyPoints(String content) {
    final sentences = content
        .split(RegExp(r'[.!?]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 20)
        .take(5)
        .toList();

    return sentences;
  }
}
