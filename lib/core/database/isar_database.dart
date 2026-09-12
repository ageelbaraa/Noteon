import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/folders/data/folder.dart';
import '../../features/notes/data/note.dart';
import '../../features/tags/data/tag.dart';
import '../constants/app_constants.dart';

/// Opens and exposes the local Isar database for Noteon.
class IsarDatabase {
  IsarDatabase._();

  static Isar? _instance;

  /// Active Isar instance. Throws if [open] has not completed.
  static Isar get instance {
    final db = _instance;
    if (db == null) {
      throw StateError('IsarDatabase has not been opened. Call open() first.');
    }
    return db;
  }

  static bool get isOpen => _instance != null;

  /// Schemas registered with this app database.
  static List<CollectionSchema<dynamic>> get schemas => [
        NoteSchema,
        FolderSchema,
        TagSchema,
      ];

  /// Opens Isar under the app documents directory (production path).
  ///
  /// Creates [AppConstants.databaseDirectoryName] if missing. Required because
  /// Isar Community 3.x does **not** create the provided directory itself.
  static Future<Isar> open() async {
    if (_instance != null) {
      return _instance!;
    }

    final docs = await getApplicationDocumentsDirectory();
    final dbDir = p.join(docs.path, AppConstants.databaseDirectoryName);
    return openInDirectory(dbDir);
  }

  /// Opens Isar in an explicit directory (used by tests and [open]).
  ///
  /// Ensures [directory] exists before calling [Isar.open].
  static Future<Isar> openInDirectory(
    String directory, {
    String name = AppConstants.databaseName,
  }) async {
    if (_instance != null) {
      if (_instance!.directory == directory && _instance!.name == name) {
        return _instance!;
      }
      await _instance!.close();
      _instance = null;
    }

    // Close a previously opened named instance that our static handle lost.
    if (Isar.instanceNames.contains(name)) {
      await Isar.getInstance(name)?.close();
    }

    final dir = Directory(directory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _instance = await Isar.open(
      schemas,
      directory: directory,
      name: name,
    );
    return _instance!;
  }

  /// Closes the database if open. Useful for tests.
  static Future<void> close({bool deleteFromDisk = false}) async {
    final db = _instance;
    if (db == null) {
      return;
    }
    await db.close(deleteFromDisk: deleteFromDisk);
    _instance = null;
  }
}
