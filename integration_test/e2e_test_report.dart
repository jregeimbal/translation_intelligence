import 'dart:io';

import 'package:flutter/foundation.dart';

/// Records individual test step outcomes and produces a structured report at
/// the end of the e2e run.
///
/// Usage:
///   final report = E2eTestReport();
///   // ... perform action & assertion ...
///   report.pass('Tap record button');
///   // or:
///   report.fail('Tap record button', 'Button was disabled');
///   report.screenshot('Tap record button', '/path/to/screenshot.png');
///   print(report.summary());
class E2eTestReport {
  final List<StepResult> _steps = [];

  /// Record a step that passed.
  void pass(String stepName) {
    _steps.add(StepResult(name: stepName, passed: true));
  }

  /// Record a step that failed, with a human-readable [reason].
  void fail(String stepName, String reason) {
    _steps.add(
      StepResult(name: stepName, passed: false, failureReason: reason),
    );
  }

  /// Attach a screenshot path to the most recent step with [stepName], or
  /// create a new passing step if none exists.
  void screenshot(String stepName, String screenshotPath) {
    final existing = _steps.lastWhere(
      (s) => s.name == stepName,
      orElse: () {
        final s = StepResult(name: stepName, passed: true);
        _steps.add(s);
        return s;
      },
    );
    existing.screenshotPaths.add(screenshotPath);
  }

  /// Whether all recorded steps passed.
  bool get allPassed => _steps.every((s) => s.passed);

  /// The overall result: `PASS` or `FAIL`.
  String get result => allPassed ? 'PASS' : 'FAIL';

  /// List of failed steps.
  List<StepResult> get failures =>
      _steps.where((s) => !s.passed).toList(growable: false);

  /// Returns a human-readable summary of the test run.
  String summary() {
    final buf = StringBuffer()
      ..writeln('═══════════════════════════════════════════')
      ..writeln('  E2E Test Report')
      ..writeln('═══════════════════════════════════════════')
      ..writeln('Result: $result')
      ..writeln(
        'Steps:  ${_steps.length} total, '
        '${_steps.where((s) => s.passed).length} passed, '
        '${failures.length} failed',
      )
      ..writeln('───────────────────────────────────────────');

    for (final step in _steps) {
      final icon = step.passed ? '✅' : '❌';
      buf.writeln('$icon ${step.name}');
      if (!step.passed && step.failureReason != null) {
        buf.writeln('   Reason: ${step.failureReason}');
      }
      for (final path in step.screenshotPaths) {
        buf.writeln('   📸 $path');
      }
    }

    buf.writeln('═══════════════════════════════════════════');
    return buf.toString();
  }

  /// Writes the summary to a file at [outputPath].
  ///
  /// On Android the default writes to the system temp directory which is
  /// writable by the app process. On other platforms it defaults to
  /// `build/e2e_report.txt`.
  Future<void> writeToFile([String? outputPath]) async {
    final path =
        outputPath ??
        (Platform.isAndroid
            ? '${Directory.systemTemp.path}/e2e_report.txt'
            : 'build/e2e_report.txt');
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(summary());
    debugPrint('E2E report written to ${file.absolute.path}');
  }
}

class StepResult {
  StepResult({required this.name, required this.passed, this.failureReason});

  final String name;
  final bool passed;
  final String? failureReason;
  final List<String> screenshotPaths = [];
}
