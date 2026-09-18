import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

/// Locates the Isar core binary shipped with isar_community_flutter_libs
/// (Windows) or downloads the official core binary (Linux/macOS CI).
String? bundledIsarLibraryPath() {
  final pubCache = Platform.environment['PUB_CACHE'] ??
      (Platform.isWindows
          ? p.join(Platform.environment['LOCALAPPDATA']!, 'Pub', 'Cache')
          : p.join(Platform.environment['HOME']!, '.pub-cache'));
  final hosted = Directory(p.join(pubCache, 'hosted', 'pub.dev'));
  if (!hosted.existsSync()) {
    return null;
  }
  final matches = hosted
      .listSync()
      .whereType<Directory>()
      .where(
        (d) => p.basename(d.path).startsWith('isar_community_flutter_libs-'),
      )
      .toList()
    ..sort((a, b) => b.path.compareTo(a.path));

  for (final packageDir in matches) {
    final candidates = <String>[
      if (Platform.isWindows) p.join(packageDir.path, 'windows', 'libisar.dll'),
      if (Platform.isLinux)
        p.join(packageDir.path, 'linux', 'libisar.so'),
      if (Platform.isMacOS)
        p.join(packageDir.path, 'macos', 'libisar.dylib'),
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }
  }
  return null;
}

Future<void> initializeIsarForTests() async {
  final bundled = bundledIsarLibraryPath();
  if (bundled != null && Platform.isWindows) {
    await Isar.initializeIsarCore(
      libraries: {
        Abi.windowsX64: bundled,
        Abi.windowsArm64: bundled,
      },
    );
    return;
  }
  if (bundled != null && Platform.isLinux) {
    await Isar.initializeIsarCore(
      libraries: {
        Abi.linuxX64: bundled,
        Abi.linuxArm64: bundled,
      },
    );
    return;
  }
  if (bundled != null && Platform.isMacOS) {
    await Isar.initializeIsarCore(
      libraries: {
        Abi.macosX64: bundled,
        Abi.macosArm64: bundled,
      },
    );
    return;
  }

  // CI / hosts without a bundled binary: download once.
  // Prefer `flutter test -j 1` when many suites call this concurrently.
  await Isar.initializeIsarCore(download: true);
}
