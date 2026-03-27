import 'package:flutter/material.dart';

import '../l10n/app_localizations_ext.dart';
import '../models/speech_connection_debug_info.dart';

class SpeechConnectionDebugDialog extends StatelessWidget {
  const SpeechConnectionDebugDialog({super.key, required this.failure});

  final SpeechConnectionStartupException failure;

  static Future<bool> showIfAvailable(
    BuildContext context,
    Object error,
  ) async {
    if (error is! SpeechConnectionStartupException) {
      return false;
    }
    if (!context.mounted) {
      return true;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SpeechConnectionDebugDialog(failure: error),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = failure.debugInfo.toDisplayEntries();

    return AlertDialog(
      title: const Text('Listening Connection Debug'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                failure.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (failure.cause != null) ...[
                const SizedBox(height: 12),
                SelectableText('Cause: ${failure.cause}'),
              ],
              const SizedBox(height: 16),
              for (final entry in entries) ...[
                SelectableText('${entry.key}: ${entry.value}'),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.close),
        ),
      ],
    );
  }
}
