#!/usr/bin/env dart
// Parses Flutter `--machine` NDJSON and optional FTL metadata into AI-friendly
// human (Markdown) + machine (JSON) CI reports.
//
// Usage:
//   dart run tool/ci/summarize_ci.dart \
//     --host-json build/ci/host_tests.ndjson \
//     --integration-json build/ci/integration_tests.ndjson \
//     --emulator-json build/ci/emulator_tests.ndjson \
//     --analyze-log build/ci/analyze.txt \
//     --ftl-json build/ci/ftl_result.json \
//     --flutter-version "3.41.7" \
//     --dart-version "3.11.5" \
//     --out build/ci

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final opts = _Args.parse(args);
  Directory(opts.outDir).createSync(recursive: true);

  final analyze = _readAnalyze(opts.analyzeLog);
  final host = _parseFlutterMachine(opts.hostJson, suiteHint: 'host');
  final integration =
      _parseFlutterMachine(opts.integrationJson, suiteHint: 'integration');
  final emulator =
      _parseFlutterMachine(opts.emulatorJson, suiteHint: 'emulator');
  final ftl = _readFtl(opts.ftlJson);

  final report = <String, Object?>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'flutterVersion': opts.flutterVersion ?? 'unknown',
    'dartVersion': opts.dartVersion ?? 'unknown',
    'analyze': analyze,
    'hostTests': host.toJson(),
    'integrationTests': integration.toJson(),
    'androidEmulator': emulator.toJson(),
    'firebaseTestLab': ftl,
    'failures': [
      ...host.failures.map((f) => f.toJson()),
      ...integration.failures.map((f) => f.toJson()),
      ...emulator.failures.map((f) {
        final j = f.toJson();
        j['device'] = 'android-emulator-ci';
        return j;
      }),
      ...((ftl['failures'] as List?)?.cast<Map<String, Object?>>() ?? const []),
    ],
  };

  final md = _renderMarkdown(report, host, integration, emulator);
  File('${opts.outDir}/ci_report.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  File('${opts.outDir}/CI_REPORT.md').writeAsStringSync(md);

  stdout.writeln(md);

  final analyzeFailed = analyze['status'] == 'FAIL';
  final hostFailed = host.failed > 0;
  final integrationFailed = integration.failed > 0;
  final emulatorFailed = emulator.failed > 0;
  final ftlFailed = ftl['status'] == 'FAIL';
  if (analyzeFailed ||
      hostFailed ||
      integrationFailed ||
      emulatorFailed ||
      ftlFailed) {
    exitCode = 1;
  }
}

class _Args {
  _Args({
    required this.outDir,
    this.hostJson,
    this.integrationJson,
    this.emulatorJson,
    this.analyzeLog,
    this.ftlJson,
    this.flutterVersion,
    this.dartVersion,
  });

  final String outDir;
  final String? hostJson;
  final String? integrationJson;
  final String? emulatorJson;
  final String? analyzeLog;
  final String? ftlJson;
  final String? flutterVersion;
  final String? dartVersion;

  static _Args parse(List<String> args) {
    String? out = 'build/ci';
    String? host;
    String? integration;
    String? emulator;
    String? analyze;
    String? ftl;
    String? flutterVersion;
    String? dartVersion;
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      String next() => args[++i];
      switch (a) {
        case '--out':
          out = next();
        case '--host-json':
          host = next();
        case '--integration-json':
          integration = next();
        case '--emulator-json':
          emulator = next();
        case '--analyze-log':
          analyze = next();
        case '--ftl-json':
          ftl = next();
        case '--flutter-version':
          flutterVersion = next();
        case '--dart-version':
          dartVersion = next();
      }
    }
    return _Args(
      outDir: out!,
      hostJson: host,
      integrationJson: integration,
      emulatorJson: emulator,
      analyzeLog: analyze,
      ftlJson: ftl,
      flutterVersion: flutterVersion,
      dartVersion: dartVersion,
    );
  }
}

String _readTextFile(String path) {
  final bytes = File(path).readAsBytesSync();
  if (bytes.isEmpty) {
    return '';
  }
  // PowerShell Tee-Object often writes UTF-16 LE with BOM.
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return String.fromCharCodes([
      for (var i = 2; i + 1 < bytes.length; i += 2)
        bytes[i] | (bytes[i + 1] << 8),
    ]);
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

Map<String, Object?> _readAnalyze(String? path) {
  if (path == null || !File(path).existsSync()) {
    return {
      'status': 'SKIP',
      'summary': 'No analyze log provided',
    };
  }
  final text = _readTextFile(path);
  final noIssues = text.contains('No issues found');
  final hasError = RegExp(r'error •|error -').hasMatch(text);
  final hasWarning = RegExp(r'warning •|warning -').hasMatch(text);
  // flutter analyze --no-fatal-infos: infos alone are acceptable for CI PASS.
  final status = text.trim().isEmpty
      ? 'SKIP'
      : (hasError || hasWarning ? 'FAIL' : 'PASS');
  return {
    'status': status,
    'summary': noIssues
        ? 'No issues found'
        : text.trim().split('\n').reversed.take(8).toList().reversed.join('\n'),
  };
}

Map<String, Object?> _readFtl(String? path) {
  if (path == null || !File(path).existsSync()) {
    return {
      'status': 'SKIP',
      'reason':
          'Firebase Test Lab did not run (missing credentials, disabled, or not requested).',
      'devices': <String>[],
      'failures': <Map<String, Object?>>[],
      'artifacts': <String>[],
    };
  }
  try {
    final raw = jsonDecode(File(path).readAsStringSync());
    if (raw is Map<String, dynamic>) {
      return Map<String, Object?>.from(raw);
    }
  } catch (e) {
    return {
      'status': 'FAIL',
      'reason': 'Could not parse FTL JSON: $e',
      'devices': <String>[],
      'failures': [
        {
          'testName': 'firebase_test_lab',
          'device': 'n/a',
          'error': 'Invalid ftl_result.json: $e',
          'classification': 'infrastructure',
          'confidence': 'high',
        },
      ],
      'artifacts': <String>[],
    };
  }
  return {
    'status': 'SKIP',
    'devices': <String>[],
    'failures': <Map<String, Object?>>[],
  };
}

class _SuiteResult {
  _SuiteResult({
    required this.passed,
    required this.failed,
    required this.skipped,
    required this.unitPassed,
    required this.unitFailed,
    required this.widgetPassed,
    required this.widgetFailed,
    required this.failures,
    required this.scenarios,
  });

  final int passed;
  final int failed;
  final int skipped;
  final int unitPassed;
  final int unitFailed;
  final int widgetPassed;
  final int widgetFailed;
  final List<_Failure> failures;
  final List<String> scenarios;

  int get total => passed + failed + skipped;

  Map<String, Object?> toJson() => {
        'status': failed > 0 ? 'FAIL' : (total == 0 ? 'SKIP' : 'PASS'),
        'passed': passed,
        'failed': failed,
        'skipped': skipped,
        'total': total,
        'unit': {
          'status': unitFailed > 0 ? 'FAIL' : 'PASS',
          'passed': unitPassed,
          'failed': unitFailed,
          'total': unitPassed + unitFailed,
        },
        'widget': {
          'status': widgetFailed > 0 ? 'FAIL' : 'PASS',
          'passed': widgetPassed,
          'failed': widgetFailed,
          'total': widgetPassed + widgetFailed,
        },
        'scenarios': scenarios,
        'failures': failures.map((f) => f.toJson()).toList(),
      };
}

class _Failure {
  _Failure({
    required this.testName,
    required this.suite,
    required this.error,
    required this.stack,
    required this.fileHint,
    required this.classification,
    required this.confidence,
  });

  final String testName;
  final String suite;
  final String error;
  final String stack;
  final String fileHint;
  final String classification;
  final String confidence;

  Map<String, Object?> toJson() => {
        'testName': testName,
        'suite': suite,
        'device': 'host',
        'error': error,
        'stack': stack,
        'logExcerpt': error,
        'fileHint': fileHint,
        'classification': classification,
        'confidence': confidence,
        'artifactHints': <String>[],
      };
}

_SuiteResult _parseFlutterMachine(String? path, {required String suiteHint}) {
  if (path == null || !File(path).existsSync()) {
    return _SuiteResult(
      passed: 0,
      failed: 0,
      skipped: 0,
      unitPassed: 0,
      unitFailed: 0,
      widgetPassed: 0,
      widgetFailed: 0,
      failures: const [],
      scenarios: const [],
    );
  }

  final lines = _readTextFile(path).split('\n');
  final tests = <int, _TestInfo>{};
  var passed = 0;
  var failed = 0;
  var skipped = 0;
  var unitPassed = 0;
  var unitFailed = 0;
  var widgetPassed = 0;
  var widgetFailed = 0;
  final failures = <_Failure>[];
  final scenarios = <String>[];

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) {
      continue;
    }
    Map<String, dynamic> event;
    try {
      event = jsonDecode(trimmed) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }
    final type = event['type'] as String?;
    if (type == 'testStart') {
      final test = event['test'] as Map<String, dynamic>?;
      if (test == null) continue;
      final id = test['id'] as int?;
      final name = (test['name'] as String?) ?? 'unknown';
      final url = (test['url'] as String?) ?? '';
      if (id == null) continue;
      // Skip suite group nodes (they also emit testStart in some reporters).
      if (name.contains(' loading ') || name.endsWith('loading')) {
        continue;
      }
      tests[id] = _TestInfo(
        name: name,
        url: url,
        isWidget: _looksWidget(name, url),
      );
    } else if (type == 'testDone') {
      final id = event['testID'] as int?;
      final result = event['result'] as String? ?? 'success';
      final hidden = event['hidden'] == true;
      if (id == null || hidden) continue;
      final info = tests[id];
      if (info == null) continue;
      final isWidget = info.isWidget;
      if (result == 'success') {
        passed++;
        if (isWidget) {
          widgetPassed++;
        } else {
          unitPassed++;
        }
        scenarios.add('✓ [$suiteHint] ${info.name}');
      } else if (result == 'error' || result == 'failure') {
        failed++;
        if (isWidget) {
          widgetFailed++;
        } else {
          unitFailed++;
        }
        scenarios.add('✗ [$suiteHint] ${info.name}');
      } else {
        skipped++;
        scenarios.add('○ [$suiteHint] ${info.name}');
      }
    } else if (type == 'error') {
      final id = event['testID'] as int?;
      final error = (event['error'] as String?) ?? 'unknown error';
      final stack = (event['stackTrace'] as String?) ?? '';
      final info = id == null ? null : tests[id];
      final classification = _classify(error, stack, info?.url ?? '');
      failures.add(
        _Failure(
          testName: info?.name ?? 'test#$id',
          suite: suiteHint,
          error: error,
          stack: stack,
          fileHint: info?.url ?? '',
          classification: classification.$1,
          confidence: classification.$2,
        ),
      );
    }
  }

  return _SuiteResult(
    passed: passed,
    failed: failed,
    skipped: skipped,
    unitPassed: unitPassed,
    unitFailed: unitFailed,
    widgetPassed: widgetPassed,
    widgetFailed: widgetFailed,
    failures: failures,
    scenarios: scenarios,
  );
}

class _TestInfo {
  _TestInfo({
    required this.name,
    required this.url,
    required this.isWidget,
  });

  final String name;
  final String url;
  final bool isWidget;
}

bool _looksWidget(String name, String url) {
  final u = url.toLowerCase();
  final n = name.toLowerCase();
  if (u.contains('widget_test.dart')) return true;
  if (u.contains('browse_caret') ||
      u.contains('zoom_test') ||
      u.contains('embed_caret')) {
    return true;
  }
  if (n.contains('widget') || n.contains('pump')) return true;
  // Flutter marks widget tests under testWidgets; URL is the best signal.
  if (u.contains('/test/') &&
      (u.contains('editor') || u.contains('zoom') || u.contains('browse'))) {
    return true;
  }
  return false;
}

(String, String) _classify(String error, String stack, String url) {
  final e = error.toLowerCase();
  final s = stack.toLowerCase();
  if (e.contains('libisar') ||
      e.contains('failed to load dynamic library') ||
      e.contains('socketexception') ||
      e.contains('gradle') ||
      e.contains('sdk') ||
      e.contains('license') ||
      e.contains('gcloud') ||
      e.contains('permission denied')) {
    return ('infrastructure', 'high');
  }
  if (e.contains('timeout') || e.contains('pumpandsettle timed out')) {
    return ('flaky', 'low');
  }
  if (url.contains('integration_test') &&
      (e.contains('finder') || e.contains('could not find'))) {
    return ('test_bug', 'medium');
  }
  if (s.contains('test/') || s.contains('integration_test/')) {
    if (e.contains('expected:') || e.contains('which:')) {
      return ('application_bug', 'medium');
    }
  }
  return ('unknown', 'low');
}

String _renderMarkdown(
  Map<String, Object?> report,
  _SuiteResult host,
  _SuiteResult integration,
  _SuiteResult emulator,
) {
  final analyze = report['analyze'] as Map<String, Object?>;
  final ftl = report['firebaseTestLab'] as Map<String, Object?>;
  final failures = (report['failures'] as List).cast<Map<String, Object?>>();
  final deviceLines = <String>[
    if (emulator.total > 0)
      '- GitHub Actions Android emulator (API ${Platform.environment['EMULATOR_API_LEVEL'] ?? '30'} google_apis) — FREE',
    ...((ftl['devices'] as List?)?.map((e) => '- $e') ?? const <String>[]),
  ];
  final devices = deviceLines.isEmpty
      ? '- (none / emulator or FTL not run)'
      : deviceLines.join('\n');

  final buf = StringBuffer()
    ..writeln('# Noteon CI Report')
    ..writeln()
    ..writeln('Flutter version: `${report['flutterVersion']}`')
    ..writeln('Dart version: `${report['dartVersion']}`')
    ..writeln('Generated (UTC): `${report['generatedAt']}`')
    ..writeln()
    ..writeln('## Summary')
    ..writeln()
    ..writeln('| Check | Status | Detail |')
    ..writeln('|-------|--------|--------|')
    ..writeln(
      '| flutter analyze | **${analyze['status']}** | ${_oneLine(analyze['summary'])} |',
    )
    ..writeln(
      '| Host unit tests | **${host.toJson()['unit'] is Map ? (host.toJson()['unit'] as Map)['status'] : 'n/a'}** | ${host.unitPassed}/${host.unitPassed + host.unitFailed} passed |',
    )
    ..writeln(
      '| Host widget tests | **${host.toJson()['widget'] is Map ? (host.toJson()['widget'] as Map)['status'] : 'n/a'}** | ${host.widgetPassed}/${host.widgetPassed + host.widgetFailed} passed |',
    )
    ..writeln(
      '| Integration tests (host) | **${integration.toJson()['status']}** | ${integration.passed}/${integration.total} passed |',
    )
    ..writeln(
      '| Android emulator (FREE) | **${emulator.toJson()['status']}** | ${emulator.passed}/${emulator.total} passed |',
    )
    ..writeln(
      '| Firebase Test Lab | **${ftl['status']}** | ${_oneLine(ftl['reason'] ?? ftl['summary'] ?? '')} |',
    )
    ..writeln()
    ..writeln('## Devices tested')
    ..writeln()
    ..writeln(devices)
    ..writeln()
    ..writeln('## Scenarios')
    ..writeln();

  final scenarios = [
    ...host.scenarios,
    ...integration.scenarios,
    ...emulator.scenarios,
    ...((ftl['scenarios'] as List?)?.map((e) => '$e') ?? const []),
  ];
  if (scenarios.isEmpty) {
    buf.writeln('_No scenario lines recorded._');
  } else {
    for (final s in scenarios) {
      buf.writeln('- $s');
    }
  }

  buf
    ..writeln()
    ..writeln('## Failures')
    ..writeln();
  if (failures.isEmpty) {
    buf.writeln('_None._');
  } else {
    for (final f in failures) {
      buf
        ..writeln('### `${f['testName']}`')
        ..writeln()
        ..writeln('- Device/platform: `${f['device'] ?? 'host'}`')
        ..writeln('- Suite: `${f['suite'] ?? ''}`')
        ..writeln('- Classification: **${f['classification']}** '
            '(confidence: ${f['confidence']})')
        ..writeln('- Error:')
        ..writeln('```')
        ..writeln('${f['error']}')
        ..writeln('```');
      final stack = '${f['stack'] ?? ''}';
      if (stack.trim().isNotEmpty) {
        buf
          ..writeln('- Stack / relevant log:')
          ..writeln('```')
          ..writeln(stack.length > 4000 ? '${stack.substring(0, 4000)}…' : stack)
          ..writeln('```');
      }
      final hints = f['artifactHints'];
      if (hints is List && hints.isNotEmpty) {
        buf.writeln('- Artifacts: ${hints.join(', ')}');
      }
      buf.writeln();
    }
  }

  buf
    ..writeln('## Artifacts')
    ..writeln()
    ..writeln('- `ci_report.json` — machine-readable summary for AI agents')
    ..writeln('- `CI_REPORT.md` — this file')
    ..writeln('- GitHub Actions artifacts: `test-logs`, `android-apks`, '
        '`android-emulator-results`, `ftl-results` (when FTL ran)')
    ..writeln()
    ..writeln('## Notes for AI agents')
    ..writeln()
    ..writeln(
      '1. Prefer fixing `application_bug` over weakening assertions.',
    )
    ..writeln(
      '2. Treat `infrastructure` / missing FTL billing as setup, not product regressions.',
    )
    ..writeln(
      '3. Emulator validation ≠ physical-device UX judgment.',
    )
    ..writeln(
      '4. Do not change note schema/Delta format unless a failure proves it necessary.',
    );

  return buf.toString();
}

String _oneLine(Object? value) {
  final s = '$value'.replaceAll('\n', ' ').trim();
  if (s.length <= 120) return s;
  return '${s.substring(0, 117)}...';
}
