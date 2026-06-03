import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
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
      final lines = utf8.decode(chunk);
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
            await Future<void>.delayed(Duration.zero);
          } catch (e) {
            developer.log('Failed to parse SSE chunk: $e', name: 'SSE');
            continue;
          }
        }
      }
    }
  }
}
