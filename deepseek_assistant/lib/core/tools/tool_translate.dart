import 'tool_registry.dart';

class TranslateTool extends AiTool {
  @override
  String get name => 'translate';

  @override
  String get description =>
      '翻译文本到指定语言。需要提供目标语言代码，如 "en"、"zh"、"ja"、"ko"、"fr" 等。';

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
            'description':
                '目标语言代码，如 "en"=英语、"zh"=中文、"ja"=日语、"ko"=韩语、"fr"=法语',
          },
        },
        'required': ['text', 'target_language'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final text = args['text']?.toString() ?? '';
    final targetLang = args['target_language']?.toString() ?? '';

    const langNames = {
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
    return '请将以下文本翻译为$langName($targetLang)，只输出翻译结果：\n\n$text';
  }
}
