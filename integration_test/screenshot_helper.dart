import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol/patrol.dart';

/// Returns a writable base directory for test artifacts.
///
/// On Android the app sandbox is read-only for relative paths like `build/`,
/// so we write to the system temp directory (the app's sandbox temp dir).
String _defaultScreenshotDirectory() {
  if (Platform.isAndroid) {
    return '${Directory.systemTemp.path}/e2e_screenshots';
  }
  return 'build/e2e_screenshots';
}

/// Take a screenshot and save it under a writable directory with the given
/// [name].
///
/// Uses [IntegrationTestWidgetsFlutterBinding.takeScreenshot] when the binding
/// supports it. When running under [PatrolBinding] (which does not expose
/// screenshot capture), the call is silently skipped and the returned path
/// indicates that the screenshot was not taken.
///
/// Returns the absolute path to the saved screenshot file, or a placeholder
/// string when screenshots are unavailable.
Future<String> takeScreenshot(
  PatrolIntegrationTester $,
  String name, {
  String? directory,
}) async {
  final sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

  // Only IntegrationTestWidgetsFlutterBinding supports takeScreenshot.
  final binding = TestWidgetsFlutterBinding.instance;
  if (binding is! IntegrationTestWidgetsFlutterBinding) {
    debugPrint('Screenshot skipped (binding does not support capture): $name');
    return '<screenshot-unavailable>/$sanitized';
  }

  final dir = Directory(directory ?? _defaultScreenshotDirectory());
  final fileName = '${sanitized}_${DateTime.now().millisecondsSinceEpoch}.png';
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final filePath = '${dir.path}/$fileName';

  final bytes = await binding.takeScreenshot(sanitized);
  final file = File(filePath);
  await file.writeAsBytes(bytes);

  return filePath;
}
