import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/media_storage_service.dart';

final mediaStorageProvider = Provider<MediaStorageService>((ref) {
  return MediaStorageService();
});
