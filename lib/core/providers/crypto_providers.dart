import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crypto/note_crypto_service.dart';
import '../../features/notes/data/note_lock_service.dart';
import 'media_providers.dart';

final noteCryptoServiceProvider = Provider<NoteCryptoService>((ref) {
  return NoteCryptoService();
});

final noteLockServiceProvider = Provider<NoteLockService>((ref) {
  return NoteLockService(
    crypto: ref.watch(noteCryptoServiceProvider),
    media: ref.watch(mediaStorageProvider),
  );
});

/// Active unlocked session for the note editor (memory only).
final unlockedNoteSessionProvider =
    StateProvider<UnlockedNoteSession?>((ref) => null);
