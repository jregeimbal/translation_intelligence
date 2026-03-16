import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translation_intelligence/controllers/speech_controller.dart';
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
  const SpeechFooter({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SpeechFooterState createState() => _SpeechFooterState();
}

class _SpeechFooterState extends State<SpeechFooter> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SpeechController>();
    final speechEnabled = controller.speechEnabled;
    final speechError = controller.speechError;
    final hasMessages = controller.chatMessages.isNotEmpty;
    final speakers = controller.speakers;
    final preferred = controller.preferredSpeaker;
    final theme = Theme.of(context);
    final textRoles = resolveAppThemeTextRoles(theme);
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Clear chat',
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
                              !controller.hideTranslatedOriginalText,
                            );
                      }
                    : null,
                tooltip: 'Hide translation original text',
                icon: Icon(
                  controller.hideTranslatedOriginalText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              const SizedBox(width: 8),
              if (!speechEnabled)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      speechError.isNotEmpty
                          ? speechError
                          : 'Speech not available',
                      style: textRoles.errorText,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasMessages) ...[
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<int?>(
                      initialValue: preferred,
                      isExpanded: true,
                      icon: const SizedBox.shrink(),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        labelText: 'Primary Speaker',
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
                      items: [
                        const DropdownMenuItem<int?>(
                          value: -1,
                          child: Text('None'),
                        ),
                        ...speakers.map(
                          (s) => DropdownMenuItem<int?>(
                            value: s,
                            child: Text('Speaker ${s + 1}'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        context.read<SpeechController>().setPreferredSpeaker(
                          value,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  icon: Icon(
                    controller.audioPlaybackEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                  ),
                  tooltip: controller.audioPlaybackEnabled
                      ? 'Disable audio playback'
                      : 'Enable audio playback',
                  onPressed: () {
                    context.read<SpeechController>().setAudioPlaybackEnabled(
                      !controller.audioPlaybackEnabled,
                    );
                  },
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
