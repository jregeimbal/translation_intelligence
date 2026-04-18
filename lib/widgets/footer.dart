import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
import 'package:translation_intelligence/l10n/app_localizations_ext.dart';
import 'package:translation_intelligence/theme/app_theme_resolver.dart';

import 'recording_toggle_button.dart';

/// Footer widget containing the controls once held in the header.
///
/// Displays the microphone button and speech availability status.
///
/// Language preference controls are displayed in the chat empty-state panel.
/// This widget listens to the controller and rebuilds when relevant
/// properties change.
class SpeechFooter extends StatefulWidget {
  const SpeechFooter({
    super.key,
    this.hasSeenAudioPlaybackBluetoothNotice = false,
    this.onAudioPlaybackBluetoothNoticeSeen,
  });

  final bool hasSeenAudioPlaybackBluetoothNotice;
  final Future<void> Function()? onAudioPlaybackBluetoothNoticeSeen;

  @override
  // ignore: library_private_types_in_public_api
  _SpeechFooterState createState() => _SpeechFooterState();
}

class _SpeechFooterState extends State<SpeechFooter> {
  Future<void> _toggleAudioPlayback(bool audioPlaybackEnabled) async {
    final controller = context.read<SpeechController>();
    if (audioPlaybackEnabled) {
      controller.setAudioPlaybackEnabled(enabled: false);
      return;
    }

    if (!widget.hasSeenAudioPlaybackBluetoothNotice) {
      final shouldEnable = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(dialogContext.l10n.enableAudioPlayback),
            content: Text(dialogContext.l10n.audioPlaybackBluetoothNotice),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  MaterialLocalizations.of(dialogContext).okButtonLabel,
                ),
              ),
            ],
          );
        },
      );

      if (shouldEnable != true) return;
      await widget.onAudioPlaybackBluetoothNoticeSeen?.call();
      if (!mounted) return;
    }

    controller.setAudioPlaybackEnabled(enabled: true);
  }

  @override
  Widget build(BuildContext context) {
    final speechEnabled = context.select<SpeechController, bool>(
      (controller) => controller.speechEnabled,
    );
    final speechError = context.select<SpeechController, String>(
      (controller) => controller.speechError,
    );
    final hasMessages = context.select<SpeechController, bool>(
      (controller) => controller.chatMessages.isNotEmpty,
    );
    final speakers = context.select<SpeechController, List<int>>(
      (controller) => List<int>.unmodifiable(controller.speakers),
    );
    final preferred = context.select<SpeechController, int?>(
      (controller) => controller.preferredSpeaker,
    );
    final hideTranslatedOriginalText = context.select<SpeechController, bool>(
      (controller) => controller.hideTranslatedOriginalText,
    );
    final audioPlaybackEnabled = context.select<SpeechController, bool>(
      (controller) => controller.audioPlaybackEnabled,
    );
    final theme = Theme.of(context);
    final textRoles = resolveAppThemeTextRoles(theme);
    final l10n = context.l10n;
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasMessages) ...[
                  SizedBox(
                    width: 160,
                    child: DropdownMenuFormField<int?>(
                      initialSelection: preferred,
                      expandedInsets: EdgeInsets.zero,
                      enableSearch: false,
                      requestFocusOnTap: false,
                      textStyle: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 18,
                      ),
                      label: Text(l10n.primarySpeakerLabel),
                      inputDecorationTheme: InputDecorationThemeData(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        labelStyle: const TextStyle(fontSize: 12),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownMenuEntries: [
                        DropdownMenuEntry<int?>(
                          value: -1,
                          label: l10n.noneLabel,
                        ),
                        ...speakers.map(
                          (s) => DropdownMenuEntry<int?>(
                            value: s,
                            label: l10n.speakerLabel(s + 1),
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        context.read<SpeechController>().setPreferredSpeaker(
                          value,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!speechEnabled || speechError.isNotEmpty)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        speechError.isNotEmpty
                            ? localizedSpeechError(context, speechError)
                            : l10n.speechNotAvailable,
                        style: textRoles.errorText,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: l10n.clearChat,
                  onPressed: hasMessages
                      ? context.read<SpeechController>().clearMessages
                      : null,
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: hasMessages
                      ? () {
                          context
                              .read<SpeechController>()
                              .setHideTranslatedOriginalText(
                                enabled: !hideTranslatedOriginalText,
                              );
                        }
                      : null,
                  tooltip: l10n.hideTranslationOriginalText,
                  icon: Icon(
                    hideTranslatedOriginalText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    audioPlaybackEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                  ),
                  tooltip: audioPlaybackEnabled
                      ? l10n.disableAudioPlayback
                      : l10n.enableAudioPlayback,
                  onPressed: () => _toggleAudioPlayback(audioPlaybackEnabled),
                ),
              ],
            ),
          ),
          const Align(alignment: Alignment.center, child: SpeechFab()),
        ],
      ),
    );
  }
}
