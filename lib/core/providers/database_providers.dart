import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../features/folders/data/folder_repository.dart';
import '../../features/notes/data/note_repository.dart';
import '../../features/tags/data/tag_repository.dart';
import '../database/isar_database.dart';
import 'media_providers.dart';

/// Provides the opened Isar instance (initialized in [main] before runApp).
final isarProvider = Provider<Isar>((ref) => IsarDatabase.instance);

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(
    ref.watch(isarProvider),
    mediaStorage: ref.watch(mediaStorageProvider),
  );
});

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository(ref.watch(isarProvider));
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(ref.watch(isarProvider));
});
