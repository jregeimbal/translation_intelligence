import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/l10n/app_localizations_ext.dart';

import 'speech_connection_debug_dialog.dart';

/// Floating action button that toggles speech listening.  Holds its own listen
/// state via the controller rather than being re-built by the parent.
class SpeechFab extends StatefulWidget {
  const SpeechFab({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SpeechFabState createState() => _SpeechFabState();
}

class _SpeechFabState extends State<SpeechFab> {
  bool _processing = false;

  Widget _buildCircularWaveform(
    ThemeData theme,
    Color ringColor,
    SpeechController controller,
  ) {
    final amp = controller.amplitude.clamp(0.0, 1.0);
    final trackColor = ringColor.withValues(alpha: 0.22);
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(
        painter: _CircularWavePainter(
          amplitude: amp,
          ringColor: ringColor,
          trackColor: trackColor,
        ),
        child: Center(
          child: Icon(Icons.stop, size: 18, color: theme.colorScheme.onPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SpeechController>();
    final enabled = controller.speechEnabled;
    final isNotListening = !controller.isListening;
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.onPrimary;
    Widget child;
    if (_processing) {
      child = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: activeColor),
      );
    } else if (!isNotListening) {
      child = _buildCircularWaveform(theme, activeColor, controller);
    } else {
      child = Icon(
        Icons.mic,
        color: enabled ? activeColor : theme.colorScheme.onSurfaceVariant,
      );
    }

    return FloatingActionButton.large(
      heroTag: 'speech-fab',
      elevation: 0,
      highlightElevation: 0,
      backgroundColor: enabled
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHigh,
      foregroundColor: enabled
          ? theme.colorScheme.onPrimary
          : theme.colorScheme.onSurfaceVariant,
      shape: const CircleBorder(),
      onPressed: enabled
          ? (isNotListening
                ? () async {
                    setState(() => _processing = true);
                    try {
                      await context.read<SpeechController>().startListening();
                    } catch (error) {
                      if (!context.mounted) {
                        return;
                      }
                      final handled =
                          await SpeechConnectionDebugDialog.showIfAvailable(
                            context,
                            error,
                          );
                      if (!handled) {
                        rethrow;
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _processing = false);
                      }
                    }
                  }
                : context.read<SpeechController>().stopListening)
          : null,
      tooltip: enabled ? context.l10n.listen : context.l10n.speechUnavailable,
      child: child,
    );
  }
}

class _CircularWavePainter extends CustomPainter {

  const _CircularWavePainter({
    required this.amplitude,
    required this.ringColor,
    required this.trackColor,
  });
  final double amplitude;
  final Color ringColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final wavePaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    const segments = 20;
    final dynamicRange = 5.5 * amplitude;
    for (var i = 0; i < segments; i++) {
      final theta = (i / segments) * 2 * math.pi;
      final wave = 0.5 + 0.5 * math.sin(amplitude * 8 + i * 0.8);
      final segmentLength = 0.6 + dynamicRange * wave;

      final ux = math.cos(theta);
      final uy = math.sin(theta);
      final start = Offset(
        center.dx + ux * (radius - 4),
        center.dy + uy * (radius - 4),
      );
      final end = Offset(
        center.dx + ux * (radius - 4 + segmentLength),
        center.dy + uy * (radius - 4 + segmentLength),
      );
      canvas.drawLine(start, end, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularWavePainter other) {
    return other.amplitude != amplitude ||
        other.ringColor != ringColor ||
        other.trackColor != trackColor;
  }
}
