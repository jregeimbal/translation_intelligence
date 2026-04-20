import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations_ext.dart';

class FirstLaunchWalkthroughDialog extends StatefulWidget {
  const FirstLaunchWalkthroughDialog({super.key});

  @override
  State<FirstLaunchWalkthroughDialog> createState() =>
      _FirstLaunchWalkthroughDialogState();
}

class _FirstLaunchWalkthroughDialogState
    extends State<FirstLaunchWalkthroughDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _animateToPage(int index) async {
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final steps = [
      _WalkthroughStepData(
        icon: Icons.group_rounded,
        title: l10n.walkthroughModesTitle,
        body: l10n.walkthroughModesBody,
      ),
      _WalkthroughStepData(
        icon: Icons.language_rounded,
        title: l10n.walkthroughLanguagesTitle,
        body: l10n.walkthroughLanguagesBody,
      ),
      _WalkthroughStepData(
        icon: Icons.mic_rounded,
        title: l10n.walkthroughMicrophoneTitle,
        body: l10n.walkthroughMicrophoneBody,
      ),
      _WalkthroughStepData(
        icon: Icons.record_voice_over_rounded,
        title: l10n.walkthroughPrimarySpeakerTitle,
        body: l10n.walkthroughPrimarySpeakerBody,
      ),
    ];
    final isLastPage = _currentPage == steps.length - 1;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: math.min(MediaQuery.of(context).size.height * 0.82, 560),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.walkthroughWelcomeTitle,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.walkthroughWelcomeBody,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.walkthroughDismiss,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: steps.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final step = steps[index];
                    return _WalkthroughStep(step: step);
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < steps.length;
                            index++
                          ) ...[
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: index == _currentPage ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: index == _currentPage
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            if (index != steps.length - 1)
                              const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.walkthroughSkip),
                  ),
                  if (_currentPage > 0) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _animateToPage(_currentPage - 1),
                      child: Text(l10n.walkthroughBack),
                    ),
                  ],
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: isLastPage
                        ? () => Navigator.of(context).pop()
                        : () => _animateToPage(_currentPage + 1),
                    child: Text(
                      isLastPage
                          ? l10n.walkthroughGetStarted
                          : l10n.walkthroughNext,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalkthroughStep extends StatelessWidget {
  const _WalkthroughStep({required this.step});

  final _WalkthroughStepData step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                step.icon,
                size: 36,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              step.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                step.body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkthroughStepData {
  const _WalkthroughStepData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
