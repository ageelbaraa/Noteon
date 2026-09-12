import 'package:isar_community/isar.dart';

part 'folder.g.dart';

/// Folder used to organize notes. Supports one level of nesting via [parentFolderId].
@collection
class Folder {
  Id id = Isar.autoIncrement;

  @Index(caseSensitive: false)
  late String name;

  /// Null for root folders; set for subfolders.
  @Index()
  int? parentFolderId;

  DateTime createdAt = DateTime.now();

  DateTime updatedAt = DateTime.now();
}
