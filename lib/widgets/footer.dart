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
    final theme = Theme.of(context);
    final textRoles = resolveAppThemeTextRoles(theme);
    final tokens = resolveAppThemeTokens(theme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.footerSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      // use a stack so the mic button can float centered regardless of
      // other widgets' widths.
      child: SizedBox(
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
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
                const Spacer(),
              ],
            ),
            // floating microphone control
            Align(
              alignment: Alignment.center,
              child: const SpeechFab(),
            ),
          ],
        ),
      ),
    );
  }
}
