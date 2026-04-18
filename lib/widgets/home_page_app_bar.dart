import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../l10n/app_localizations_ext.dart';
import '../theme/app_theme_resolver.dart';

/// The app bar for the home page with logo, title, and action buttons.
class HomePageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomePageAppBar({
    super.key,
    required this.initializing,
    required this.onHelpPressed,
    required this.onDebugPressed,
    required this.onSettingsPressed,
  });

  final bool initializing;
  final VoidCallback onHelpPressed;
  final VoidCallback onDebugPressed;
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textRoles = resolveAppThemeTextRoles(theme);

    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/icon_omnialingo.png',
                filterQuality: FilterQuality.high,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.appTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                context.l10n.translationAssistant,
                style: textRoles.appSubtitle,
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (!initializing)
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: context.l10n.walkthroughHelp,
            onPressed: onHelpPressed,
          ),
        if (kDebugMode)
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: context.l10n.debugAudioStream,
            onPressed: onDebugPressed,
          ),
        if (!initializing)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: context.l10n.settingsTitle,
            onPressed: onSettingsPressed,
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
