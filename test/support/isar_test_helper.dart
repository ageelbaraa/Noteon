import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

/// Locates the Isar core DLL shipped with isar_community_flutter_libs.
String bundledIsarLibraryPath() {
  final pubCache =
      Platform.environment['PUB_CACHE'] ??
      p.join(Platform.environment['LOCALAPPDATA']!, 'Pub', 'Cache');
  final hosted = Directory(p.join(pubCache, 'hosted', 'pub.dev'));
  final matches = hosted
      .listSync()
      .whereType<Directory>()
      .where((d) => p.basename(d.path).startsWith('isar_community_flutter_libs-'))
      .toList()
    ..sort((a, b) => b.path.compareTo(a.path));

  for (final packageDir in matches) {
    final dll = File(p.join(packageDir.path, 'windows', 'libisar.dll'));
    if (dll.existsSync()) {
      return dll.path;
    }
  }

  throw StateError(
    'Could not locate libisar.dll under isar_community_flutter_libs.',
  );
}

Future<void> initializeIsarForTests() {
  final libraryPath = bundledIsarLibraryPath();
  return Isar.initializeIsarCore(
    libraries: {
      Abi.windowsX64: libraryPath,
      Abi.windowsArm64: libraryPath,
    },
  );
}
