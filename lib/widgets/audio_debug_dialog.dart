import 'package:flutter/material.dart';

import '../controllers/speech_controller.dart';
import '../controllers/two_way_chat_controller.dart';
import '../l10n/app_localizations_ext.dart';
import '../services/speech_output_provider.dart';
import '../services/speech_stt_provider.dart';
import '../services/speech_translation_provider.dart';

class AudioDebugDialog extends StatelessWidget {
  const AudioDebugDialog._({
    required this.controller,
    required this.twoWayController,
    required this.outputProvider,
    required this.sttProvider,
    required this.translationProvider,
    required this.isGroupSection,
  });

  static Future<void> showInDialog(
    BuildContext context,
    SpeechController controller,
    TwoWayChatController twoWayController,
    SpeechOutputProvider outputProvider,
    SpeechSttProvider sttProvider,
    SpeechTranslationProvider translationProvider,
    bool isGroupSection,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AudioDebugDialog._(
        controller: controller,
        twoWayController: twoWayController,
        outputProvider: outputProvider,
        sttProvider: sttProvider,
        translationProvider: translationProvider,
        isGroupSection: isGroupSection,
      ),
    );
  }

  final SpeechController controller;
  final TwoWayChatController twoWayController;
  final SpeechOutputProvider outputProvider;
  final SpeechSttProvider sttProvider;
  final SpeechTranslationProvider translationProvider;
  final bool isGroupSection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.debugAudioStream),
      content: StreamBuilder<int>(
        stream: Stream<int>.periodic(
          const Duration(milliseconds: 250),
          (count) => count,
        ),
        initialData: 0,
        builder: (context, _) {
          final startedAt = _getActiveSessionStartedAt(
            controller,
            twoWayController,
            isGroupSection,
          );
          final elapsed = startedAt == null
              ? null
              : DateTime.now().difference(startedAt);
          final elapsedLabel = elapsed == null
              ? l10n.notAvailableShort
              : '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

          final rows = <MapEntry<String, String>>[
            MapEntry(
              l10n.debugSection,
              isGroupSection
                  ? l10n.debugSectionGroup
                  : l10n.debugSectionTwoWay,
            ),
            MapEntry(
              l10n.debugListeningActive,
              _getIsActiveListening(controller, twoWayController, isGroupSection)
                  ? l10n.yes
                  : l10n.no,
            ),
            MapEntry(
              l10n.debugSttProvider,
              _getActiveSessionSttProvider(
                controller,
                twoWayController,
                isGroupSection,
              ) == null
                  ? l10n.notAvailableShort
                  : localizedSttProviderLabel(
                      context,
                      _getActiveSessionSttProvider(
                        controller,
                        twoWayController,
                        isGroupSection,
                      )!,
                    ),
            ),
            MapEntry(
              l10n.debugSourceLanguage,
              _getActiveSessionSourceLanguage(
                controller,
                twoWayController,
                isGroupSection,
              ) == null
                  ? l10n.notAvailableShort
                  : localizedRecognitionLocaleLabel(
                      context,
                      _getActiveSessionSourceLanguage(
                        controller,
                        twoWayController,
                        isGroupSection,
                      )!,
                    ),
            ),
            MapEntry(
              l10n.debugResolvedLanguageCode,
              _getActiveSessionResolvedLanguageCode(
                controller,
                twoWayController,
                isGroupSection,
              ) ?? l10n.notAvailableShort,
            ),
            MapEntry(
              l10n.debugActiveSampleRate,
              _getActiveSessionSampleRate(controller, twoWayController,
                      isGroupSection) ==
                  null
                  ? l10n.notAvailableShort
                  : l10n.sampleRateHertz(
                      _getActiveSessionSampleRate(
                        controller,
                        twoWayController,
                        isGroupSection,
                      )!,
                    ),
            ),
            MapEntry(
              l10n.debugListeningDeviceId,
              _getActiveSessionListeningDeviceId(
                controller,
                twoWayController,
                isGroupSection,
              ) ?? l10n.autoDefault,
            ),
            MapEntry(
              l10n.debugAmplitude,
              _getActiveAmplitude(controller, twoWayController, isGroupSection)
                  .toStringAsFixed(3),
            ),
            MapEntry(l10n.debugSessionElapsed, elapsedLabel),
            MapEntry(
              l10n.debugSessionStartedAt,
              _getActiveSessionStartedAt(
                controller,
                twoWayController,
                isGroupSection,
              )?.toIso8601String() ?? l10n.notAvailableShort,
            ),
            MapEntry(
              l10n.debugConfiguredSttProvider,
              isGroupSection
                  ? localizedSttProviderLabel(
                      context,
                      controller.sttProvider,
                    )
                  : localizedSttProviderLabel(
                      context,
                      twoWayController.sttProvider,
                    ),
            ),
            MapEntry(
              l10n.debugConfiguredDeepgramLanguage,
              isGroupSection
                  ? localizedDeepgramLanguageLabel(
                      context,
                      controller.deepgramRecognitionLanguage,
                    )
                  : localizedDeepgramLanguageLabel(
                      context,
                      twoWayController.deepgramRecognitionLanguage,
                    ),
            ),
            MapEntry(
              l10n.debugConfiguredGoogleLocale,
              isGroupSection
                  ? localizedRecognitionLocaleLabel(
                      context,
                      controller.speechToTextRecognitionLocale,
                    )
                  : localizedRecognitionLocaleLabel(
                      context,
                      twoWayController.speechToTextRecognitionLocale,
                    ),
            ),
            MapEntry(
              l10n.debugConfiguredSttLocale,
              isGroupSection
                  ? localizedRecognitionLocaleLabel(
                      context,
                      controller.speechToTextRecognitionLocale,
                    )
                  : localizedRecognitionLocaleLabel(
                      context,
                      twoWayController.speechToTextRecognitionLocale,
                    ),
            ),
          ];

          return SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final row in rows) ...[
                    Text('${row.key}: ${row.value}'),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  bool _getIsActiveListening(
    SpeechController controller,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? controller.isListening
        : twoWayController.isListening;
  }

  SpeechSttProvider? _getActiveSessionSttProvider(
    SpeechController controller,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? controller.activeSessionSttProvider
        : twoWayController.activeSessionSttProvider;
  }

  String? _getActiveSessionSourceLanguage(
    SpeechController controller,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? controller.activeSessionSourceLanguage
        : twoWayController.activeSessionSourceLanguage;
  }

  String? _getActiveSessionResolvedLanguageCode(
    SpeechController controller,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? controller.activeSessionResolvedLanguageCode
        : twoWayController.activeSessionResolvedLanguageCode;
  }

  int? _getActiveSessionSampleRate(
    SpeechController controller,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? controller.activeSessionSampleRate
        : twoWayController.activeSessionSampleRate;
  }

  String? _getActiveSessionListeningDeviceId(
    SpeechController controller,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? controller.activeSessionListeningDeviceId
        : twoWayController.activeSessionListeningDeviceId;
  }

  DateTime? _getActiveSessionStartedAt(
    SpeechController controller,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? controller.activeSessionStartedAt
        : twoWayController.activeSessionStartedAt;
  }

  double _getActiveAmplitude(
    SpeechController controller,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? controller.amplitude
        : twoWayController.amplitude;
  }
}
