import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/speech_controller.dart';
import '../theme/app_theme_resolver.dart';

/// A small bar displayed above the chat that provides controls which
/// affect the conversation.  It is only visible when there are existing
/// messages in the chat.
class ChatControlBar extends StatefulWidget {
  const ChatControlBar({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ChatControlBarState createState() => _ChatControlBarState();
}

class _ChatControlBarState extends State<ChatControlBar> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SpeechController>();
    final hasMessages = controller.chatMessages.isNotEmpty;
    if (!hasMessages) return const SizedBox.shrink();

    final speakers = controller.speakers;
    final preferred = controller.preferredSpeaker;
    final theme = Theme.of(context);
    final tokens = resolveAppThemeTokens(theme);

    return Card(
      margin: EdgeInsets.zero,
      color: tokens.glassSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Row(
          children: [
            Text('Primary speaker', style: theme.textTheme.bodyMedium),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: preferred,
                icon: const SizedBox.shrink(),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
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
                    child: Text('No alignment'),
                  ),
                  ...speakers.map(
                    (s) => DropdownMenuItem<int?>(
                      value: s,
                      child: Text('Speaker ${s + 1}'),
                    ),
                  ),
                ],
                onChanged: context.read<SpeechController>().setPreferredSpeaker,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
