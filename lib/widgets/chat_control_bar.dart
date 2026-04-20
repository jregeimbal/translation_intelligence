import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translation_intelligence/l10n/app_localizations_ext.dart';

import 'package:translation_intelligence/controllers/group_chat_controller.dart';
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
    final controller = context.watch<GroupChatController>();
    final hasMessages = controller.chatMessages.isNotEmpty;
    if (!hasMessages) return const SizedBox.shrink();

    final speakers = controller.speakers;
    final preferred = controller.preferredSpeaker;
    final theme = Theme.of(context);
    final tokens = resolveAppThemeTokens(theme);
    final l10n = context.l10n;

    return Card(
      margin: EdgeInsets.zero,
      color: tokens.glassSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Row(
          children: [
            Text(l10n.primarySpeakerInline, style: theme.textTheme.bodyMedium),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownMenuFormField<int?>(
                initialSelection: preferred,
                expandedInsets: EdgeInsets.zero,
                enableSearch: false,
                requestFocusOnTap: false,
                textStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 18),
                inputDecorationTheme: InputDecorationThemeData(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
                  DropdownMenuEntry<int?>(value: -1, label: l10n.noAlignment),
                  ...speakers.map(
                    (s) => DropdownMenuEntry<int?>(
                      value: s,
                      label: l10n.speakerLabel(s + 1),
                    ),
                  ),
                ],
                onSelected: context
                    .read<GroupChatController>()
                    .setPreferredSpeaker,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
