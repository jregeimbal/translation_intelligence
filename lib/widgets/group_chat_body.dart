import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/speech_controller.dart';
import 'chat_message.dart';
import 'group_language_bar.dart';

/// The group chat body with language bar and message list.
class GroupChatBody extends StatelessWidget {
  const GroupChatBody({
    super.key,
    required this.controller,
    required this.canSwapGroupLanguages,
    required this.onSourceSelected,
    required this.onTargetSelected,
    required this.onSwap,
  });

  final SpeechController controller;
  final bool Function(Map<String, String>) canSwapGroupLanguages;
  final Future<void> Function(String value) onSourceSelected;
  final void Function(String value) onTargetSelected;
  final Future<void> Function()? onSwap;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SpeechController>.value(
      value: controller,
      child: Padding(
        key: const ValueKey('group_chat'),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12),
        child: Column(
          children: [
            GroupLanguageBar(
              sourceLanguages: controller.deepgramRecognitionLanguages,
              targetLanguages: SpeechController.supportedLanguages,
              sourceCode: controller.deepgramRecognitionLanguage,
              targetCode: controller.targetLanguage,
              canSwap: canSwapGroupLanguages(
                controller.deepgramRecognitionLanguages,
              ),
              onSourceSelected: onSourceSelected,
              onTargetSelected: onTargetSelected,
              onSwap: onSwap,
            ),
            const SizedBox(height: 10),
            const Expanded(child: ChatMessageList()),
          ],
        ),
      ),
    );
  }
}
