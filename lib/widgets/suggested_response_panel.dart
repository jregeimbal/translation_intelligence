import 'package:flutter/material.dart';

import '../models/suggested_response.dart';
import '../l10n/app_localizations_ext.dart';

/// A panel that displays a suggested response with its original and translated
/// text, along with a countdown timer and close button.
class SuggestedResponsePanel extends StatelessWidget {
  const SuggestedResponsePanel({
    super.key,
    required this.event,
    required this.title,
    required this.closeTooltip,
    required this.onClose,
    required this.timeout,
  });

  final SuggestedResponseEvent event;
  final String title;
  final String closeTooltip;
  final VoidCallback onClose;
  final Duration timeout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sourceLanguageLabel = localizedAppLanguageName(
      context,
      event.response.sourceLanguageCode,
    );
    final targetLanguageLabel = localizedAppLanguageName(
      context,
      event.response.targetLanguageCode,
    );

    return Material(
      key: const Key('suggested-response-panel'),
      color: colorScheme.inverseSurface,
      elevation: 6,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1, end: 0),
                  duration: timeout,
                  builder: (context, remaining, child) {
                    return SizedBox(
                      width: 28,
                      height: 28,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CircularProgressIndicator(
                              key: const Key(
                                'suggested-response-timeout-progress',
                              ),
                              value: remaining,
                              strokeWidth: 2,
                              backgroundColor: colorScheme.onInverseSurface
                                  .withValues(alpha: 0.18),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.onInverseSurface.withValues(
                                  alpha: 0.82,
                                ),
                              ),
                            ),
                          ),
                          child!,
                        ],
                      ),
                    );
                  },
                  child: IconButton(
                    tooltip: closeTooltip,
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    iconSize: 20,
                    splashRadius: 16,
                    visualDensity: VisualDensity.standard,
                    icon: Icon(
                      Icons.close,
                      color: colorScheme.onInverseSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.suggestedResponseOriginalLabel(sourceLanguageLabel),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onInverseSurface.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event.response.originalText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onInverseSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.suggestedResponseTranslatedLabel(
                targetLanguageLabel,
              ),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onInverseSurface.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event.response.translatedText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onInverseSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
