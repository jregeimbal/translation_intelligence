import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract interface class MicActivationSoundPlayer {
  Future<void> play();

  Future<void> dispose();
}

class DefaultMicActivationSoundPlayer implements MicActivationSoundPlayer {
  AudioPlayer? _audioPlayer;

  static final Uint8List _toneBytes = _buildToneWav();

  @override
  Future<void> play() async {
    try {
      _audioPlayer ??= AudioPlayer();
      final player = _audioPlayer!;
      final playbackContext =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? AudioContextConfig(
              focus: AudioContextConfigFocus.mixWithOthers,
            ).build()
          : null;
      await player.stop();
      await player.play(BytesSource(_toneBytes), ctx: playbackContext);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await _audioPlayer?.dispose();
    _audioPlayer = null;
  }

  static Uint8List _buildToneWav() {
    const sampleRate = 16000;
    const durationMs = 140;
    const channels = 1;
    const bitsPerSample = 16;
    const primaryFrequencyHz = 620.0;
    const secondaryFrequencyHz = 420.0;
    const peakAmplitude = 0.16;

    final sampleCount = (sampleRate * durationMs / 1000).round();
    final dataSize = sampleCount * channels * (bitsPerSample ~/ 8);
    final bytes = ByteData(44 + dataSize);

    void writeAscii(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        bytes.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    writeAscii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, channels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(
      28,
      sampleRate * channels * (bitsPerSample ~/ 8),
      Endian.little,
    );
    bytes.setUint16(32, channels * (bitsPerSample ~/ 8), Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);

    for (var sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
      final progress = sampleIndex / sampleCount;
      final envelope = math.pow(math.sin(math.pi * progress), 1.8) as double;
      final primary = math.sin(
        2 * math.pi * primaryFrequencyHz * sampleIndex / sampleRate,
      );
      final secondary = math.sin(
        2 * math.pi * secondaryFrequencyHz * sampleIndex / sampleRate,
      );
      final sample = primary * 0.78 + secondary * 0.22;
      final value = (sample * envelope * peakAmplitude * 32767).round().clamp(
        -32768,
        32767,
      );
      bytes.setInt16(44 + sampleIndex * 2, value, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }
}