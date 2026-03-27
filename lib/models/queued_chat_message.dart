import 'chat_message.dart';

class QueuedChatMessage {
  QueuedChatMessage({
    required this.id,
    required this.original,
    required this.speaker,
    this.translation,
    this.processingStarted = false,
    this.sourceLanguageCode,
    this.targetLanguageCode,
    List<ChatMessageGroup>? groups,
  }) : groups =
           groups ??
           [
             ChatMessageGroup(
               id: '${id}_g0',
               original: original,
               translation: translation,
             ),
           ];

  final String id;
  String original;
  final int? speaker;
  String? translation;
  bool processingStarted;
  List<ChatMessageGroup> groups;
  final String? sourceLanguageCode;
  final String? targetLanguageCode;

  ChatMessage toChatMessage({required bool isFinal}) {
    return ChatMessage(
      original,
      speaker: speaker,
      isFinal: isFinal,
      id: id,
      groups: groups,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
    )..translation = translation;
  }
}
