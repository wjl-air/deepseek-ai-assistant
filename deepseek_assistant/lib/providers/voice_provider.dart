import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceState { idle, listening, speaking, error }

class VoiceData {
  final VoiceState status;
  final String recognizedText;

  VoiceData({this.status = VoiceState.idle, this.recognizedText = ''});

  VoiceData copyWith({VoiceState? status, String? recognizedText}) {
    return VoiceData(
      status: status ?? this.status,
      recognizedText: recognizedText ?? this.recognizedText,
    );
  }
}

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceData>((ref) {
  return VoiceNotifier();
});

class VoiceNotifier extends StateNotifier<VoiceData> {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  VoiceNotifier() : super(VoiceData()) {
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage('zh-CN');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<bool> initSpeech() async {
    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          state = state.copyWith(status: VoiceState.idle);
        }
      },
      onError: (_) {
        state = state.copyWith(status: VoiceState.error);
      },
    );
    return available;
  }

  Future<String> startListening() async {
    state = VoiceData(status: VoiceState.listening);

    await _speechToText.listen(
      onResult: (result) {
        state = state.copyWith(
          recognizedText: result.recognizedWords,
          status: result.finalResult ? VoiceState.idle : VoiceState.listening,
        );
      },
      listenMode: stt.ListenMode.dictation,
    );

    return state.recognizedText;
  }

  Future<String> stopListening() async {
    await _speechToText.stop();
    final text = state.recognizedText;
    state = VoiceData(status: VoiceState.idle, recognizedText: text);
    return text;
  }

  Future<void> speak(String text) async {
    state = state.copyWith(status: VoiceState.speaking);
    await _flutterTts.speak(text);
    _flutterTts.setCompletionHandler(() {
      state = state.copyWith(status: VoiceState.idle);
    });
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    state = state.copyWith(status: VoiceState.idle);
  }

  bool get isAvailable => _speechToText.isAvailable;

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
