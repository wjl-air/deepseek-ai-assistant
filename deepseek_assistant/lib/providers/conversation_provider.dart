import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/storage/local_storage_service.dart';
import '../data/repositories/chat_repository.dart';

final conversationRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(LocalStorageService.instance);
});
