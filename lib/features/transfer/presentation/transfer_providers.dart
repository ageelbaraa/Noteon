import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/media_providers.dart';
import '../data/backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    isar: ref.watch(isarProvider),
    media: ref.watch(mediaStorageProvider),
    crypto: ref.watch(noteCryptoServiceProvider),
  );
});
