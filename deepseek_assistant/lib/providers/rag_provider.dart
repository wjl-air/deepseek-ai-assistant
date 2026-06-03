import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/rag_search_result.dart';

enum RagStatus { idle, searching, error }

class RagState {
  final RagStatus status;
  final RagSearchResult? lastResult;
  final String? errorMessage;
  final bool ragEnabled;

  RagState({
    this.status = RagStatus.idle,
    this.lastResult,
    this.errorMessage,
    this.ragEnabled = true,
  });

  RagState copyWith({
    RagStatus? status,
    RagSearchResult? lastResult,
    String? errorMessage,
    bool? ragEnabled,
  }) {
    return RagState(
      status: status ?? this.status,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: errorMessage ?? this.errorMessage,
      ragEnabled: ragEnabled ?? this.ragEnabled,
    );
  }
}

class RagNotifier extends StateNotifier<RagState> {
  RagNotifier() : super(RagState());

  void setRagEnabled(bool enabled) {
    state = state.copyWith(ragEnabled: enabled);
  }

  void setSearching() {
    state = state.copyWith(
      status: RagStatus.searching,
      errorMessage: null,
    );
  }

  void setResult(RagSearchResult result) {
    state = state.copyWith(
      status: RagStatus.idle,
      lastResult: result,
      errorMessage: null,
    );
  }

  void setError(String error) {
    state = state.copyWith(
      status: RagStatus.error,
      errorMessage: error,
    );
  }

  void reset() {
    state = RagState(ragEnabled: state.ragEnabled);
  }
}

final ragProvider = StateNotifierProvider<RagNotifier, RagState>((ref) {
  return RagNotifier();
});
