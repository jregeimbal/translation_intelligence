import 'package:flutter/material.dart';

import '../l10n/app_localizations_ext.dart';
import '../theme/app_theme_resolver.dart';
import 'searchable_selection_field.dart';

class GroupLanguageBar extends StatelessWidget {
  final Map<String, String> sourceLanguages;
  final List<String> targetLanguages;
  final String sourceCode;
  final String targetCode;
  final bool canSwap;
  final Future<void> Function(String value) onSourceSelected;
  final void Function(String value) onTargetSelected;
  final Future<void> Function()? onSwap;

  const GroupLanguageBar({
    super.key,
    required this.sourceLanguages,
    required this.targetLanguages,
    required this.sourceCode,
    required this.targetCode,
    required this.canSwap,
    required this.onSourceSelected,
    required this.onTargetSelected,
    this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = resolveAppThemeTokens(theme);
    final fieldTheme = InputDecorationThemeData(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      labelStyle: const TextStyle(fontSize: 12),
      floatingLabelStyle: const TextStyle(fontSize: 12),
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
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.glassSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: SearchableSelectionField<String>(
              title: context.l10n.sourceLabel,
              searchHintText: context.l10n.languageSearchHint,
              emptyText: context.l10n.noMatchingLanguages,
              selectedValue: sourceCode,
              selectedLabel: localizedDeepgramLanguageLabel(
                context,
                sourceCode,
              ),
              labelText: context.l10n.sourceLabel,
              textStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 18),
              inputDecorationTheme: fieldTheme,
              options: sourceLanguages.entries
                  .map(
                    (entry) => SearchableSelectionOption<String>(
                      value: entry.value,
                      label: localizedDeepgramLanguageLabel(
                        context,
                        entry.value,
                      ),
                      supportingText:
                          localizedDeepgramLanguageHelperText(
                            context,
                            entry.value,
                          ) ??
                          entry.value,
                      searchTerms: [
                        entry.key,
                        entry.value,
                        localizedDeepgramLanguageHelperText(
                              context,
                              entry.value,
                            ) ??
                            '',
                      ],
                    ),
                  )
                  .toList(growable: false),
              onSelected: (value) async {
                if (value == sourceCode) return;
                await onSourceSelected(value);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: canSwap
                ? context.l10n.swapLanguagesTooltip
                : (sourceCode == 'multi' || targetCode == 'multi'
                      ? context.l10n.swapUnavailableMultiTooltip
                      : context.l10n.swapUnavailablePairTooltip),
            onPressed: canSwap && onSwap != null ? () async => onSwap!() : null,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SearchableSelectionField<String>(
              title: context.l10n.targetLabel,
              searchHintText: context.l10n.languageSearchHint,
              emptyText: context.l10n.noMatchingLanguages,
              selectedValue: targetCode,
              selectedLabel: localizedAppLanguageName(context, targetCode),
              labelText: context.l10n.targetLabel,
              textStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 18),
              inputDecorationTheme: fieldTheme,
              options: targetLanguages
                  .map(
                    (languageCode) => SearchableSelectionOption<String>(
                      value: languageCode,
                      label: localizedAppLanguageName(context, languageCode),
                      supportingText: languageCode,
                      searchTerms: [languageCode],
                    ),
                  )
                  .toList(growable: false),
              onSelected: (value) {
                if (value == targetCode) return;
                onTargetSelected(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
