import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:noteon/core/database/database_open_failure.dart';

void main() {
  test('maps path-related errors to DB_PATH', () {
    expect(
      DatabaseOpenFailure.codeFor(
        const FileSystemException('No such file or directory'),
      ),
      'DB_PATH',
    );
  });

  test('maps IsarError to DB_ISAR', () {
    expect(
      DatabaseOpenFailure.codeFor(IsarError('something went wrong')),
      'DB_ISAR',
    );
  });

  test('maps native library failures to DB_NATIVE', () {
    expect(
      DatabaseOpenFailure.codeFor(Exception('Failed to load dynamic library')),
      'DB_NATIVE',
    );
  });
}
