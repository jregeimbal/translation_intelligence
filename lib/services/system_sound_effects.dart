import 'package:flutter/services.dart';

Future<void> playMicActivationSound() async {
  try {
    await SystemSound.play(SystemSoundType.click);
  } catch (_) {}
}
