import 'package:flutter/services.dart';

/// Plays a lightweight system click when mic listening is activated.
///
/// Failures are intentionally ignored so unsupported platforms or channel
/// issues do not block the primary action of starting microphone capture.
Future<void> playMicActivationSound() async {
  try {
    await SystemSound.play(SystemSoundType.click);
  } catch (_) {}
}
