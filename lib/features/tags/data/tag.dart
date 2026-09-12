import 'package:isar_community/isar.dart';

part 'tag.g.dart';

/// Tag/label that can be attached to many notes.
@collection
class Tag {
  Id id = Isar.autoIncrement;

  @Index(unique: true, caseSensitive: false)
  late String name;

  DateTime createdAt = DateTime.now();
}
