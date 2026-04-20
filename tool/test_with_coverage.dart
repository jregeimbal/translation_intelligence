import 'dart:io';

Future<void> main() async {
  final testProcess = await Process.start('flutter', const [
    'test',
    '--coverage',
    'test/',
  ], mode: ProcessStartMode.inheritStdio);

  final testExitCode = await testProcess.exitCode;

  final coverageFile = File('coverage/lcov.info');
  if (!coverageFile.existsSync()) {
    stderr.writeln('Coverage file not found at coverage/lcov.info');
    exit(testExitCode == 0 ? 1 : testExitCode);
  }

  final lines = await coverageFile.readAsLines();
  var linesFound = 0;
  var linesHit = 0;

  for (final line in lines) {
    if (line.startsWith('LF:')) {
      linesFound += int.tryParse(line.substring(3)) ?? 0;
    } else if (line.startsWith('LH:')) {
      linesHit += int.tryParse(line.substring(3)) ?? 0;
    }
  }

  if (linesFound == 0) {
    stderr.writeln('Unable to compute coverage: LF total is 0.');
    exit(testExitCode == 0 ? 1 : testExitCode);
  }

  final percentage = (linesHit / linesFound) * 100;
  stdout.writeln(
    'Total coverage: ${percentage.toStringAsFixed(2)}% '
    '($linesHit/$linesFound lines)',
  );

  exit(testExitCode);
}
