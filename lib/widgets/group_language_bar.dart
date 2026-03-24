import 'package:flutter/material.dart';

import '../l10n/app_localizations_ext.dart';
import '../theme/app_theme_resolver.dart';

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
            child: DropdownMenuFormField<String>(
              initialSelection: sourceCode,
              expandedInsets: EdgeInsets.zero,
              enableSearch: false,
              requestFocusOnTap: false,
              textStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 18),
              label: Text(context.l10n.sourceLabel),
              inputDecorationTheme: fieldTheme,
              dropdownMenuEntries: sourceLanguages.entries
                  .map(
                    (entry) => DropdownMenuEntry<String>(
                      value: entry.value,
                      label: localizedDeepgramLanguageLabel(
                        context,
                        entry.value,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onSelected: (value) async {
                if (value == null || value == sourceCode) return;
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
            child: DropdownMenuFormField<String>(
              initialSelection: targetCode,
              expandedInsets: EdgeInsets.zero,
              enableSearch: false,
              requestFocusOnTap: false,
              textStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 18),
              label: Text(context.l10n.targetLabel),
              inputDecorationTheme: fieldTheme,
              dropdownMenuEntries: targetLanguages
                  .map(
                    (languageCode) => DropdownMenuEntry<String>(
                      value: languageCode,
                      label: localizedAppLanguageName(context, languageCode),
                    ),
                  )
                  .toList(growable: false),
              onSelected: (value) {
                if (value == null || value == targetCode) return;
                onTargetSelected(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
