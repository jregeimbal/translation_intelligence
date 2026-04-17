import 'package:flutter/material.dart';

import '../l10n/app_localizations_ext.dart';
import '../models/suggested_response.dart';
import '../widgets/suggested_response_panel.dart';

/// The bottom navigation bar with suggested response panel and footer.
class HomePageBottomBar extends StatelessWidget {
  const HomePageBottomBar({
    super.key,
    required this.activeSuggestedResponse,
    required this.suggestedResponseKey,
    required this.onCloseSuggestedResponse,
    required this.showFooter,
    required this.footerChild,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final SuggestedResponseEvent? activeSuggestedResponse;
  final int suggestedResponseKey;
  final VoidCallback onCloseSuggestedResponse;
  final bool showFooter;
  final Widget? footerChild;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: activeSuggestedResponse == null
                  ? const SizedBox.shrink()
                  : Padding(
                      key: ValueKey<int>(suggestedResponseKey),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SuggestedResponsePanel(
                        event: activeSuggestedResponse!,
                        title: context.l10n.suggestedResponseTitle,
                        closeTooltip: context.l10n.close,
                        onClose: onCloseSuggestedResponse,
                        timeout: const Duration(seconds: 10),
                      ),
                    ),
            ),
            if (showFooter && footerChild != null) ...[
              footerChild!,
              const SizedBox(height: 8),
            ],
            NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations,
            ),
          ],
        ),
      ),
    );
  }
}
