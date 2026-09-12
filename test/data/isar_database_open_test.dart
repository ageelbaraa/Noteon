import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/core/constants/app_constants.dart';
import 'package:noteon/core/database/isar_database.dart';
import 'package:noteon/features/notes/data/note_repository.dart';
import 'package:path/path.dart' as p;

import '../support/isar_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUpAll(() async {
    await initializeIsarForTests();
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('noteon_db_open_');
  });

  tearDown(() async {
    await IsarDatabase.close(deleteFromDisk: true);
    if (await root.exists()) {
      try {
        await root.delete(recursive: true);
      } catch (_) {
        // Windows may briefly lock files after Isar close; ignore cleanup races.
      }
    }
  });

  test('openInDirectory creates a missing nested folder before Isar.open',
      () async {
    // Mimic production: documents root exists, noteon_db child does not.
    final nested = p.join(root.path, AppConstants.databaseDirectoryName);
    expect(Directory(nested).existsSync(), isFalse);

    final name = 'noteon_mkdir_${DateTime.now().microsecondsSinceEpoch}';
    final isar = await IsarDatabase.openInDirectory(nested, name: name);

    expect(Directory(nested).existsSync(), isTrue);
    expect(isar.isOpen, isTrue);

    final notes = NoteRepository(isar);
    final id = await notes.create(title: 'Persists after mkdir fix');
    expect(await notes.getById(id), isNotNull);
  });

  test('opening again after close reuses a freshly created directory', () async {
    final nested = p.join(root.path, AppConstants.databaseDirectoryName);
    final name = 'noteon_reopen_${DateTime.now().microsecondsSinceEpoch}';

    await IsarDatabase.openInDirectory(nested, name: name);
    final notes = NoteRepository(IsarDatabase.instance);
    final id = await notes.create(title: 'Keep me');
    await IsarDatabase.close();

    await IsarDatabase.openInDirectory(nested, name: name);
    final reloaded = await NoteRepository(IsarDatabase.instance).getById(id);
    expect(reloaded?.title, 'Keep me');
  });
}
