class ChatMessageGroup {
  final String id;
  final String original;
  final String? translation;

  const ChatMessageGroup({
    required this.id,
    required this.original,
    this.translation,
  });

  factory ChatMessageGroup.fromJson(Map<String, dynamic> json) {
    return ChatMessageGroup(
      id: json['id'] as String,
      original: json['original'] as String,
      translation: json['translation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'original': original, 'translation': translation};
  }
}

class ChatMessage {
  static int _nextMessageId = 0;

  final String id;
  String original;
  bool isFinal;
  String? translation;
  final DateTime timestamp;
  final List<ChatMessageGroup> groups;
  final String? sourceLanguageCode;
  final String? targetLanguageCode;

  final int? speaker;

  ChatMessage(
    this.original, {
    this.speaker,
    this.isFinal = false,
    String? id,
    DateTime? timestamp,
    List<ChatMessageGroup>? groups,
    this.sourceLanguageCode,
    this.targetLanguageCode,
  }) : id = id ?? 'msg_${_nextMessageId++}',
       timestamp = timestamp ?? DateTime.now(),
       groups = List<ChatMessageGroup>.unmodifiable(groups ?? const []);

  @override
  String toString() {
    if (speaker != null) {
      return 'Speaker ${speaker! + 1}: $original';
    }
    return original;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      json['original'] as String,
      speaker: json['speaker'] as int?,
      isFinal: json['isFinal'] as bool? ?? false,
      id: json['id'] as String?,
      timestamp: json['timestamp'] is String
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
      sourceLanguageCode: json['sourceLanguageCode'] as String?,
      targetLanguageCode: json['targetLanguageCode'] as String?,
      groups: ((json['groups'] as List?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ChatMessageGroup.fromJson)
          .toList(growable: false),
    )..translation = json['translation'] as String?;
  }

  Map<String, dynamic> toJson() {
    return {
      'original': original,
      'speaker': speaker,
      'isFinal': isFinal,
      'translation': translation,
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      if (sourceLanguageCode != null) 'sourceLanguageCode': sourceLanguageCode,
      if (targetLanguageCode != null) 'targetLanguageCode': targetLanguageCode,
      'groups': groups.map((group) => group.toJson()).toList(growable: false),
    };
  }
}
