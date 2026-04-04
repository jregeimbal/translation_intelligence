import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/group_controller.dart';
import '../controllers/two_way_chat_controller.dart';
import '../l10n/app_localizations_ext.dart';
import '../services/speech_stt_provider.dart';

class AudioDebugDialog extends StatelessWidget {
  const AudioDebugDialog._({required this.isGroupSection});

  static Future<void> showInDialog(
    BuildContext context, {
    required bool isGroupSection,
  }) async {
    final groupController = context.read<GroupController>();
    final twoWayController = context.read<TwoWayChatController>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => MultiProvider(
        providers: [
          ChangeNotifierProvider<GroupController>.value(
            value: groupController,
          ),
          ChangeNotifierProvider<TwoWayChatController>.value(
            value: twoWayController,
          ),
        ],
        child: AudioDebugDialog._(isGroupSection: isGroupSection),
      ),
    );
  }

  final bool isGroupSection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groupController = context.read<GroupController>();
    final twoWayController = context.read<TwoWayChatController>();

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
            groupController,
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
              isGroupSection ? l10n.debugSectionGroup : l10n.debugSectionTwoWay,
            ),
            MapEntry(
              l10n.debugListeningActive,
              _getIsActiveListening(
                  groupController,
                    twoWayController,
                    isGroupSection,
                  )
                  ? l10n.yes
                  : l10n.no,
            ),
            MapEntry(
              l10n.debugSttProvider,
              _getActiveSessionSttProvider(
                        groupController,
                        twoWayController,
                        isGroupSection,
                      ) ==
                      null
                  ? l10n.notAvailableShort
                  : localizedSttProviderLabel(
                      context,
                      _getActiveSessionSttProvider(
                        groupController,
                        twoWayController,
                        isGroupSection,
                      )!,
                    ),
            ),
            MapEntry(
              l10n.debugSourceLanguage,
              _getActiveSessionSourceLanguage(
                        groupController,
                        twoWayController,
                        isGroupSection,
                      ) ==
                      null
                  ? l10n.notAvailableShort
                  : localizedRecognitionLocaleLabel(
                      context,
                      _getActiveSessionSourceLanguage(
                        groupController,
                        twoWayController,
                        isGroupSection,
                      )!,
                    ),
            ),
            MapEntry(
              l10n.debugResolvedLanguageCode,
              _getActiveSessionResolvedLanguageCode(
                  groupController,
                    twoWayController,
                    isGroupSection,
                  ) ??
                  l10n.notAvailableShort,
            ),
            MapEntry(
              l10n.debugActiveSampleRate,
              _getActiveSessionSampleRate(
                        groupController,
                        twoWayController,
                        isGroupSection,
                      ) ==
                      null
                  ? l10n.notAvailableShort
                  : l10n.sampleRateHertz(
                      _getActiveSessionSampleRate(
                        groupController,
                        twoWayController,
                        isGroupSection,
                      )!,
                    ),
            ),
            MapEntry(
              l10n.debugListeningDeviceId,
              _getActiveSessionListeningDeviceId(
                  groupController,
                    twoWayController,
                    isGroupSection,
                  ) ??
                  l10n.autoDefault,
            ),
            MapEntry(
              l10n.debugAmplitude,
              _getActiveAmplitude(
                groupController,
                twoWayController,
                isGroupSection,
              ).toStringAsFixed(3),
            ),
            MapEntry(l10n.debugSessionElapsed, elapsedLabel),
            MapEntry(
              l10n.debugSessionStartedAt,
              _getActiveSessionStartedAt(
                  groupController,
                    twoWayController,
                    isGroupSection,
                  )?.toIso8601String() ??
                  l10n.notAvailableShort,
            ),
            MapEntry(
              l10n.debugConfiguredSttProvider,
              isGroupSection
                  ? localizedSttProviderLabel(
                    context,
                    groupController.sttProvider,
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
                      groupController.deepgramRecognitionLanguage,
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
                      groupController.speechToTextRecognitionLocale,
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
                      groupController.speechToTextRecognitionLocale,
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
    GroupController groupController,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? groupController.isListening
        : twoWayController.isListening;
  }

  SpeechSttProvider? _getActiveSessionSttProvider(
    GroupController groupController,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? groupController.activeSessionSttProvider
        : twoWayController.activeSessionSttProvider;
  }

  String? _getActiveSessionSourceLanguage(
    GroupController groupController,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? groupController.activeSessionSourceLanguage
        : twoWayController.activeSessionSourceLanguage;
  }

  String? _getActiveSessionResolvedLanguageCode(
    GroupController groupController,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? groupController.activeSessionResolvedLanguageCode
        : twoWayController.activeSessionResolvedLanguageCode;
  }

  int? _getActiveSessionSampleRate(
    GroupController groupController,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? groupController.activeSessionSampleRate
        : twoWayController.activeSessionSampleRate;
  }

  String? _getActiveSessionListeningDeviceId(
    GroupController groupController,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? groupController.activeSessionListeningDeviceId
        : twoWayController.activeSessionListeningDeviceId;
  }

  DateTime? _getActiveSessionStartedAt(
    GroupController groupController,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? groupController.activeSessionStartedAt
        : twoWayController.activeSessionStartedAt;
  }

  double _getActiveAmplitude(
    GroupController groupController,
    TwoWayChatController twoWayController,
    bool isGroupSection,
  ) {
    return isGroupSection
        ? groupController.amplitude
        : twoWayController.amplitude;
  }
}
