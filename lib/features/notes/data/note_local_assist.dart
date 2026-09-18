/// Local-only note text helpers (no network / no model APIs).
abstract final class NoteLocalAssist {
  /// Collapse excess blank lines and trim trailing spaces per line.
  static String tidyWhitespace(String input) {
    final lines = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t]+$'), ''))
        .toList();
    final out = <String>[];
    var blankRun = 0;
    for (final line in lines) {
      if (line.trim().isEmpty) {
        blankRun++;
        if (blankRun <= 1) {
          out.add('');
        }
      } else {
        blankRun = 0;
        out.add(line.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trimRight());
      }
    }
    return out.join('\n').trim();
  }

  /// Turns non-empty lines into a bullet list (skips lines that already look listed).
  static String toBulletList(String input) {
    final lines = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final out = <String>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        out.add('');
        continue;
      }
      final trimmed = line.trimLeft();
      if (RegExp(r'^([-*•]|\d+[.)])\s+').hasMatch(trimmed)) {
        out.add(line);
      } else {
        out.add('• $trimmed');
      }
    }
    return out.join('\n').trim();
  }

  /// Promotes the first non-empty line to a short title-ish form (sentence case trim).
  static String emphasizeFirstLine(String input) {
    final lines = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final i = lines.indexWhere((l) => l.trim().isNotEmpty);
    if (i < 0) {
      return input.trim();
    }
    final first = lines[i].trim();
    lines[i] = first;
    if (i + 1 < lines.length && lines[i + 1].trim().isNotEmpty) {
      lines.insert(i + 1, '');
    }
    return lines.join('\n').trim();
  }
}
