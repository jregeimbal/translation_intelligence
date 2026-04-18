// Standard Flutter integration test driver.
//
// This file enables running integration tests on a connected device via:
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/e2e_test.dart
//
// For Patrol-based device testing, prefer:
//   patrol test --target integration_test/e2e_test.dart
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
