import '../widgets/chat_message.dart';

class QueuedChatMessage {
  QueuedChatMessage({
    required this.original,
    required this.speaker,
    this.translation,
    this.processingStarted = false,
  });

  String original;
  final int? speaker;
  String? translation;
  bool processingStarted;

  ChatMessage toChatMessage({required bool isFinal}) {
    return ChatMessage(
      original,
      speaker: speaker,
      isFinal: isFinal,
    )..translation = translation;
  }
}