import 'package:isar_community/isar.dart';

part 'media_ref.g.dart';

/// Filesystem reference for an image or sketch stored outside Isar.
///
/// Media bytes live under the app documents directory; only the relative path
/// and metadata are persisted in the database.
@embedded
class MediaRef {
  MediaRef();

  /// Path relative to the Noteon media root (e.g. `images/abc.jpg`).
  String relativePath = '';

  /// Logical media kind: `image` or `sketch`.
  String kind = 'image';

  DateTime? createdAt;
}
