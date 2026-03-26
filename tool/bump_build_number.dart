import 'dart:io';

void main() {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('pubspec.yaml not found in ${Directory.current.path}.');
    exitCode = 1;
    return;
  }

  final originalContent = pubspecFile.readAsStringSync();
  final versionPattern = RegExp(
    r'^version:\s*([^\s#]+)(\s*#.*)?$',
    multiLine: true,
  );
  final match = versionPattern.firstMatch(originalContent);
  if (match == null) {
    stderr.writeln('No version entry found in pubspec.yaml.');
    exitCode = 1;
    return;
  }

  final currentVersion = match.group(1)!;
  final lineSuffix = match.group(2) ?? '';
  final buildPattern = RegExp(r'^(.*)\+(\d+)$');
  final buildMatch = buildPattern.firstMatch(currentVersion);

  final nextVersion = switch (buildMatch) {
    final buildMatch? =>
      '${buildMatch.group(1)}+${int.parse(buildMatch.group(2)!) + 1}',
    null => '$currentVersion+1',
  };

  final updatedContent = originalContent.replaceFirst(
    versionPattern,
    'version: $nextVersion$lineSuffix',
  );

  if (updatedContent == originalContent) {
    stdout.writeln('pubspec.yaml version unchanged.');
    return;
  }

  pubspecFile.writeAsStringSync(updatedContent);
  stdout.writeln(
    'Updated pubspec.yaml build number: $currentVersion -> $nextVersion',
  );
}
