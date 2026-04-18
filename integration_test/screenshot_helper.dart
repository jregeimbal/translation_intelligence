import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol/patrol.dart';

/// Directory where e2e screenshots are stored during a test run.
const String screenshotDirectory = 'build/e2e_screenshots';

/// Take a screenshot using [IntegrationTestWidgetsFlutterBinding] and save it
/// under [screenshotDirectory] with the given [name].
///
/// Returns the absolute path to the saved screenshot file.
Future<String> takeScreenshot(
  PatrolTester $,
  String name, {
  String directory = screenshotDirectory,
}) async {
  final sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  final fileName = '${sanitized}_${DateTime.now().millisecondsSinceEpoch}.png';
  final dir = Directory(directory);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final filePath = '${dir.path}/$fileName';

  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  final bytes = await binding.takeScreenshot(sanitized);
  final file = File(filePath);
  await file.writeAsBytes(bytes);

  return filePath;
}
